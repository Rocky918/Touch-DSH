import Foundation

public enum DSHLight: String, Sendable {
    case offline, idle, working, waiting, error
}

public struct DSHSnapshot: Equatable, Sendable {
    public var light: DSHLight
    public var serverOnline: Bool
    public var pid: Int32?
    public var detail: String

    public init(light: DSHLight, serverOnline: Bool, pid: Int32? = nil, detail: String = "") {
        self.light = light
        self.serverOnline = serverOnline
        self.pid = pid
        self.detail = detail
    }
}

public struct DSHEventReducer: Sendable {
    private var approvals = Set<String>()
    private var questions = Set<String>()
    private var errorSessions = Set<String>()
    private var globalError = false

    public init() {}

    public mutating func consume(_ object: [String: Any], now: Date = Date()) {
        guard let payload = (object["payload"] as? [String: Any]) ?? (object["value"] as? [String: Any]) ?? findFrame(in: object),
              let type = payload["type"] as? String else { return }
        let rpcId = (object["rpcId"] as? String) ?? UUID().uuidString
        switch type {
        case "approval/requested": approvals.insert(payload["approvalId"] as? String ?? rpcId)
        case "approval/resolved": if let id = payload["approvalId"] as? String { approvals.remove(id) }
        case "question/requested": questions.insert(rpcId)
        case "question/resolved": if let id = payload["questionRpcId"] as? String { questions.remove(id) }
        case "host/agent-error":
            if let sessionId = payload["sessionId"] as? String { errorSessions.insert(sessionId) }
            else { globalError = true }
        case "stream/error": globalError = true
        case "session/event": consumeSessionEvent(payload)
        default: break
        }
    }

    public func light(serverOnline: Bool, anyRunning: Bool, unhealthy: Bool, now: Date = Date()) -> DSHLight {
        if !serverOnline { return .offline }
        if unhealthy { return .error }
        if !approvals.isEmpty || !questions.isEmpty { return .waiting }
        if globalError || !errorSessions.isEmpty { return .error }
        return anyRunning ? .working : .idle
    }

    public mutating func serverStopped() {
        approvals.removeAll()
        questions.removeAll()
        errorSessions.removeAll()
        globalError = false
    }

    private mutating func consumeSessionEvent(_ payload: [String: Any]) {
        guard let sessionId = payload["sessionId"] as? String,
              let event = payload["event"] as? [String: Any],
              let eventType = event["type"] as? String else { return }
        switch eventType {
        case "turn/start":
            errorSessions.remove(sessionId)
            globalError = false
        case "turn/end":
            let data = event["data"] as? [String: Any]
            let reason = data?["reason"] as? [String: Any]
            let kind = reason?["kind"] as? String
            if let kind, ["error", "blocked", "interrupted", "aborted", "max-tokens"].contains(kind) {
                errorSessions.insert(sessionId)
            } else if kind == "completed" {
                errorSessions.remove(sessionId)
            }
        default: break
        }
    }

    private func findFrame(in object: [String: Any]) -> [String: Any]? {
        if object["type"] is String { return object }
        for value in object.values {
            if let child = value as? [String: Any], let found = findFrame(in: child) { return found }
        }
        return nil
    }
}

public enum DSHProcessIdentity {
    public static func isOwnedDSHWeb(command: String, processUser: String, currentUser: String) -> Bool {
        guard processUser.trimmingCharacters(in: .whitespacesAndNewlines) == currentUser else { return false }
        let lower = command.lowercased()
        let isDSH = lower.contains("@deepseek-ai/dsh") || lower.contains("/bin/dsh") || lower.contains("dsh/lib/bin.js")
        let isWeb = lower.split(whereSeparator: { $0.isWhitespace }).contains("web")
        return isDSH && isWeb
    }
}
