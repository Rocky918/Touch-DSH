import AppKit
import TouchDSHCore

@MainActor
public final class DSHMonitor: NSObject {
    public var onChange: ((DSHSnapshot) -> Void)?
    public private(set) var snapshot = DSHSnapshot(light: .offline, serverOnline: false, detail: "DSH 未启动")
    private var timer: Timer?
    private var reducer = DSHEventReducer()
    private var stream: EventStream?
    private var consecutiveHealthFailures = 0
    private var latestPID: Int32?
    private var latestOnline = false
    private var latestRunning = false
    private var latestForeignListener = false
    private var workingHoldUntil = Date.distantPast
    private var recoveredSessions = Set<String>()

    public func start() {
        refresh()
        timer = .scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    public func stop() {
        timer?.invalidate()
        stream?.stop()
    }

    public func refresh() {
        Task { [weak self] in
            let listener = await Task.detached { ProcessTools.listenerOn3080() }.value
            let health = await DSHAPI.sessionState()
            guard let self else { return }
            let recognizedPID = listener.flatMap { info in
                DSHProcessIdentity.isOwnedDSHWeb(command: info.command, processUser: info.user, currentUser: NSUserName()) ? info.pid : nil
            }
            let verifiedOnline = health.online && recognizedPID != nil
            self.latestPID = recognizedPID
            self.latestOnline = verifiedOnline
            self.latestForeignListener = listener != nil && recognizedPID == nil
            if !verifiedOnline {
                self.latestRunning = false
                self.workingHoldUntil = .distantPast
                if listener == nil {
                    self.reducer.serverStopped()
                    self.recoveredSessions.removeAll()
                }
            } else if health.anyRunning {
                self.latestRunning = true
                self.workingHoldUntil = Date().addingTimeInterval(3.5)
            } else if Date() >= self.workingHoldUntil {
                self.latestRunning = false
            }
            if health.online { self.consecutiveHealthFailures = 0 } else if listener != nil { self.consecutiveHealthFailures += 1 }
            if verifiedOnline && self.stream == nil {
                self.stream = EventStream { [weak self] event in
                    Task { @MainActor in
                        guard let self else { return }
                        self.reducer.consume(event)
                        self.recoverStateIfNeeded(from: event)
                        self.publish(pid: self.latestPID, online: self.latestOnline, running: self.latestRunning,
                                     foreignListener: self.latestForeignListener)
                    }
                } onEnded: { [weak self] in
                    Task { @MainActor in
                        self?.stream = nil
                        self?.recoveredSessions.removeAll()
                    }
                }
                self.stream?.start()
            } else if !verifiedOnline {
                self.stream?.stop()
                self.stream = nil
            }
            self.publish(pid: recognizedPID, online: verifiedOnline, running: self.latestRunning,
                         foreignListener: self.latestForeignListener)
        }
    }

    private func recoverStateIfNeeded(from envelope: [String: Any]) {
        guard let payload = envelope["payload"] as? [String: Any],
              payload["type"] as? String == "session/subscribed",
              let sessionId = payload["sessionId"] as? String,
              recoveredSessions.insert(sessionId).inserted else { return }
        Task { [weak self] in
            let events = await DSHAPI.latestTurnEvents(sessionId: sessionId)
            guard let self, self.latestOnline else { return }
            for event in events {
                self.reducer.consume(["payload": [
                    "type": "session/event", "sessionId": sessionId, "event": event
                ]])
            }
            self.publish(pid: self.latestPID, online: self.latestOnline, running: self.latestRunning,
                         foreignListener: self.latestForeignListener)
        }
    }

    private func publish(pid: Int32?, online: Bool, running: Bool, foreignListener: Bool = false) {
        let unhealthy = foreignListener || (pid != nil && consecutiveHealthFailures >= 2)
        let light = reducer.light(serverOnline: online, anyRunning: running, unhealthy: unhealthy)
        let detail: String
        switch light {
        case .offline: detail = foreignListener ? "3080 端口被其他程序占用" : "DSH 未启动"
        case .idle: detail = "DSH 后台空闲"
        case .working: detail = "DSH 正在工作"
        case .waiting: detail = "DSH 等待确认"
        case .error: detail = "DSH 运行异常"
        }
        let next = DSHSnapshot(light: light, serverOnline: online, pid: pid, detail: detail)
        if next != snapshot {
            snapshot = next
            onChange?(next)
        }
    }
}

private enum DSHAPI {
    struct Health { let online: Bool; let anyRunning: Bool }

    static func sessionState() async -> Health {
        guard let url = URL(string: "http://127.0.0.1:3080/api/session.list") else { return Health(online: false, anyRunning: false) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 1
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "type": "client-request", "rpcId": UUID().uuidString, "method": "session.list", "payload": [:]
        ])
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return Health(online: false, anyRunning: false)
            }
            let result = root["result"] as? [String: Any]
            let value = result?["value"] as? [String: Any]
            let items = value?["items"] as? [[String: Any]] ?? []
            return Health(online: true, anyRunning: items.contains { $0["running"] as? Bool == true })
        } catch {
            return Health(online: false, anyRunning: false)
        }
    }

    static func latestTurnEvents(sessionId: String) async -> [[String: Any]] {
        guard let url = URL(string: "http://127.0.0.1:3080/api/session.history") else { return [] }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 2
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "type": "client-request",
            "rpcId": UUID().uuidString,
            "method": "session.history",
            "payload": ["sessionId": sessionId, "maxMessages": 1]
        ])
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let result = root["result"] as? [String: Any],
                  result["ok"] as? Bool == true,
                  let value = result["value"] as? [String: Any],
                  let entries = value["events"] as? [[String: Any]] else { return [] }
            return entries.compactMap { $0["event"] as? [String: Any] }
        } catch {
            return []
        }
    }
}

private final class EventStream: @unchecked Sendable {
    private let onEvent: ([String: Any]) -> Void
    private let onEnded: () -> Void
    private var session: URLSession?
    private var tasks: [URLSessionWebSocketTask] = []
    private var stopped = false

    init(onEvent: @escaping ([String: Any]) -> Void, onEnded: @escaping () -> Void) {
        self.onEvent = onEvent
        self.onEnded = onEnded
    }

    func start() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 86_400
        session = URLSession(configuration: config)
        for path in ["events.mux", "events.host"] {
            guard let url = URL(string: "ws://127.0.0.1:3080/api/\(path)") else { continue }
            let task = session!.webSocketTask(with: url)
            tasks.append(task)
            task.resume()
            receive(from: task)
        }
    }

    func stop() {
        stopped = true
        tasks.forEach { $0.cancel() }
        session?.invalidateAndCancel()
    }

    private func receive(from task: URLSessionWebSocketTask) {
        task.receive { [weak self, weak task] result in
            guard let self, let task else { return }
            switch result {
            case .success(let message):
                let data: Data?
                switch message {
                case .string(let text): data = text.data(using: .utf8)
                case .data(let bytes): data = bytes
                @unknown default: data = nil
                }
                if let data, let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    self.onEvent(object)
                }
                if !self.stopped { self.receive(from: task) }
            case .failure:
                self.tasks.removeAll { $0 === task }
                if !self.stopped && self.tasks.isEmpty { self.onEnded() }
            }
        }
    }
}
