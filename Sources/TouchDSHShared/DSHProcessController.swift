import AppKit
import Darwin
import TouchDSHCore

struct ListenerInfo: Equatable {
    let pid: Int32
    let user: String
    let command: String
    let startTime: String
}

enum ProcessTools {
    static func run(_ executable: String, _ arguments: [String]) -> String? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            return String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        } catch { return nil }
    }

    static func listenerOn3080() -> ListenerInfo? {
        guard let raw = run("/usr/sbin/lsof", ["-nP", "-iTCP:3080", "-sTCP:LISTEN", "-Fpu"]),
              let pLine = raw.split(separator: "\n").first(where: { $0.first == "p" }),
              let pid = Int32(pLine.dropFirst()) else { return nil }
        return processInfo(pid: pid)
    }

    static func processInfo(pid: Int32) -> ListenerInfo? {
        guard let ps = run("/bin/ps", ["-p", String(pid), "-o", "user=", "-o", "command="])?.trimmingCharacters(in: .whitespacesAndNewlines),
              let split = ps.firstIndex(where: { $0.isWhitespace }) else { return nil }
        let user = String(ps[..<split])
        let command = String(ps[split...]).trimmingCharacters(in: .whitespaces)
        guard let startTime = run("/bin/ps", ["-p", String(pid), "-o", "lstart="])?.trimmingCharacters(in: .whitespacesAndNewlines),
              !startTime.isEmpty else { return nil }
        return ListenerInfo(pid: pid, user: user, command: command, startTime: startTime)
    }

    static func isSameProcess(_ expected: ListenerInfo) -> Bool {
        processInfo(pid: expected.pid) == expected
    }
}

@MainActor
public final class DSHProcessController {
    public static let logURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/Touch DSH/dsh-web.log")
    private static let maxLogBytes: UInt64 = 5 * 1_024 * 1_024
    private let monitor: DSHMonitor
    public private(set) var isStarting = false
    public private(set) var isStopping = false
    private var lastWebOpenAt = Date.distantPast
    public var onOperationChange: (() -> Void)?
    public init(monitor: DSHMonitor) { self.monitor = monitor }

    public func startDSH() {
        guard !monitor.snapshot.serverOnline, !isStarting, !isStopping else { return }
        guard let binary = locateBinary() else {
            alert(title: "找不到 DSH", message: "请先安装 DeepSeek Harness，或确认 dsh 命令位于 ~/.nvm 下。")
            return
        }
        do {
            let logURL = try Self.prepareLogForLaunch()
            let handle = try FileHandle(forWritingTo: logURL)
            try handle.seekToEnd()
            let process = Process()
            process.executableURL = binary
            process.arguments = ["web", "--no-open"]
            process.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
            var environment = ProcessInfo.processInfo.environment
            let binaryDirectory = binary.deletingLastPathComponent().path
            let inheritedPath = environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
            let pathEntries = inheritedPath.split(separator: ":").map(String.init)
            if !pathEntries.contains(binaryDirectory) {
                environment["PATH"] = "\(binaryDirectory):\(inheritedPath)"
            }
            process.environment = environment
            process.standardOutput = handle
            process.standardError = handle
            isStarting = true
            onOperationChange?()
            process.terminationHandler = { [weak self] terminatedProcess in
                Task { @MainActor in
                    guard let self, !self.monitor.snapshot.serverOnline else { return }
                    self.isStarting = false
                    self.onOperationChange?()
                    self.monitor.refresh()
                    if terminatedProcess.terminationStatus != 0 {
                        self.alert(
                            title: "DSH 启动失败",
                            message: "DSH 启动后立即退出（代码 \(terminatedProcess.terminationStatus)）。请通过菜单栏打开 DSH 日志查看详情。"
                        )
                    }
                }
            }
            try process.run()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in self?.monitor.refresh() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
                guard let self, self.isStarting, !self.monitor.snapshot.serverOnline else { return }
                self.isStarting = false
                self.onOperationChange?()
            }
        } catch {
            isStarting = false
            onOperationChange?()
            alert(title: "DSH 启动失败", message: error.localizedDescription)
        }
    }

    public func openWeb() {
        guard monitor.snapshot.serverOnline else { return }
        let now = Date()
        guard now.timeIntervalSince(lastWebOpenAt) >= 1.5 else { return }
        lastWebOpenAt = now
        if let url = URL(string: "http://127.0.0.1:3080/") { NSWorkspace.shared.open(url) }
    }

    public func observe(_ snapshot: DSHSnapshot) {
        if snapshot.serverOnline && isStarting {
            isStarting = false
            onOperationChange?()
        }
        if !snapshot.serverOnline && isStopping {
            isStopping = false
            onOperationChange?()
        }
    }

    public func requestSafeQuit() {
        guard let listener = ProcessTools.listenerOn3080() else {
            alert(title: "DSH 未在运行", message: "没有发现监听 3080 端口的后台进程。")
            return
        }
        guard DSHProcessIdentity.isOwnedDSHWeb(command: listener.command, processUser: listener.user, currentUser: NSUserName()) else {
            alert(title: "已阻止退出", message: "3080 端口上的进程不是当前用户启动的 DSH Web，组件不会操作它。")
            return
        }
        let confirm = NSAlert()
        confirm.messageText = "彻底退出 DSH？"
        confirm.informativeText = "将安全停止 PID \(listener.pid) 的 DSH 后台服务；不会关闭其他 Node 程序。"
        confirm.addButton(withTitle: "安全退出")
        confirm.addButton(withTitle: "取消")
        guard confirm.runModal() == .alertFirstButtonReturn else { return }
        guard ProcessTools.isSameProcess(listener) else {
            alert(title: "已阻止退出", message: "确认期间 DSH 进程身份发生变化，组件没有发送停止信号。")
            monitor.refresh()
            return
        }
        isStopping = true
        onOperationChange?()
        guard Darwin.kill(listener.pid, SIGTERM) == 0 else {
            isStopping = false
            onOperationChange?()
            alert(title: "无法退出 DSH", message: String(cString: strerror(errno)))
            return
        }
        waitForExit(expected: listener, remaining: 10)
    }

    private func waitForExit(expected: ListenerInfo, remaining: Int) {
        if Darwin.kill(expected.pid, 0) != 0 {
            isStopping = false
            onOperationChange?()
            monitor.refresh()
            return
        }
        guard remaining > 0 else {
            guard ProcessTools.isSameProcess(expected),
                  DSHProcessIdentity.isOwnedDSHWeb(command: expected.command, processUser: expected.user, currentUser: NSUserName()) else {
                isStopping = false
                onOperationChange?()
                alert(title: "已阻止强制退出", message: "DSH 进程身份已经变化，组件没有发送强制停止信号。")
                monitor.refresh()
                return
            }
            let force = NSAlert()
            force.messageText = "DSH 没有及时退出"
            force.informativeText = "已等待 5 秒。是否强制停止刚才确认的 PID \(expected.pid)？"
            force.addButton(withTitle: "强制停止")
            force.addButton(withTitle: "保留运行")
            if force.runModal() == .alertFirstButtonReturn {
                guard ProcessTools.isSameProcess(expected) else {
                    isStopping = false
                    onOperationChange?()
                    alert(title: "已阻止强制退出", message: "进程身份在最终确认后发生变化。")
                    monitor.refresh()
                    return
                }
                _ = Darwin.kill(expected.pid, SIGKILL)
                monitor.refresh()
            }
            else { isStopping = false; onOperationChange?() }
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.waitForExit(expected: expected, remaining: remaining - 1)
        }
    }

    public static func ensureLogFile() throws -> URL {
        let fm = FileManager.default
        let directory = logURL.deletingLastPathComponent()
        try fm.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        if !fm.fileExists(atPath: logURL.path) {
            guard fm.createFile(atPath: logURL.path, contents: nil, attributes: [.posixPermissions: 0o600]) else {
                throw CocoaError(.fileWriteUnknown)
            }
        }
        try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: logURL.path)
        return logURL
    }

    private static func prepareLogForLaunch() throws -> URL {
        let fm = FileManager.default
        let url = try ensureLogFile()
        let attributes = try fm.attributesOfItem(atPath: url.path)
        if let size = attributes[.size] as? NSNumber, size.uint64Value >= maxLogBytes {
            let backup = url.appendingPathExtension("1")
            if fm.fileExists(atPath: backup.path) { try fm.removeItem(at: backup) }
            try fm.moveItem(at: url, to: backup)
            guard fm.createFile(atPath: url.path, contents: nil, attributes: [.posixPermissions: 0o600]) else {
                throw CocoaError(.fileWriteUnknown)
            }
        }
        return url
    }

    private func locateBinary() -> URL? {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let candidates = [
            "/opt/homebrew/bin/dsh",
            "/usr/local/bin/dsh",
            home.appendingPathComponent(".volta/bin/dsh").path,
            home.appendingPathComponent(".local/bin/dsh").path,
            home.appendingPathComponent("Library/pnpm/dsh").path,
            home.appendingPathComponent(".asdf/shims/dsh").path
        ]
        for path in candidates where fm.isExecutableFile(atPath: path) { return URL(fileURLWithPath: path) }
        let nvm = fm.homeDirectoryForCurrentUser.appendingPathComponent(".nvm/versions/node")
        let versions = (try? fm.contentsOfDirectory(at: nvm, includingPropertiesForKeys: nil)) ?? []
        for version in versions.sorted(by: {
            $0.lastPathComponent.compare($1.lastPathComponent, options: .numeric) == .orderedDescending
        }) {
            let path = version.appendingPathComponent("bin/dsh")
            if fm.isExecutableFile(atPath: path.path) { return path }
        }
        return nil
    }

    private func alert(title: String, message: String) {
        let alert = NSAlert(); alert.messageText = title; alert.informativeText = message; alert.runModal()
    }
}
