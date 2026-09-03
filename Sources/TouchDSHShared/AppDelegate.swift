import AppKit
import TouchDSHCore
import ServiceManagement

@MainActor
public protocol DSHStatusPresenting: AnyObject {
    func update(_ snapshot: DSHSnapshot)
}

public enum DeepSeekLogo {
    public static func image(size: CGFloat) -> NSImage? {
        let bundleName = "TouchDSH_TouchDSHShared.bundle"
        let bundleURLs = [
            Bundle.main.resourceURL?.appendingPathComponent(bundleName, isDirectory: true),
            Bundle.main.bundleURL.appendingPathComponent(bundleName, isDirectory: true)
        ].compactMap { $0 }

        for bundleURL in bundleURLs {
            guard let resourceBundle = Bundle(url: bundleURL),
                  let imageURL = resourceBundle.url(forResource: "DeepSeekMenuBar", withExtension: "svg"),
                  let image = NSImage(contentsOf: imageURL) else { continue }
            image.size = NSSize(width: size, height: size)
            return image
        }

        return nil
    }
}

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    public typealias StatusPresenterFactory = (DSHMonitor, DSHProcessController) -> any DSHStatusPresenting

    private let applicationName: String
    private let statusPresenterFactory: StatusPresenterFactory?
    private let monitor = DSHMonitor()
    private lazy var processController = DSHProcessController(monitor: monitor)
    private var statusPresenter: (any DSHStatusPresenting)?
    private var statusItem: NSStatusItem?
    private var startMenuItem: NSMenuItem?
    private var openMenuItem: NSMenuItem?
    private var quitDSHMenuItem: NSMenuItem?
    private var loginItem: NSMenuItem?
    private var logoSource: NSImage?
    private var latestSnapshot = DSHSnapshot(light: .offline, serverOnline: false, detail: "DSH 未启动")
    private var iconTimer: Timer?
    private var iconPhase = true

    public init(applicationName: String, statusPresenterFactory: StatusPresenterFactory? = nil) {
        self.applicationName = applicationName
        self.statusPresenterFactory = statusPresenterFactory
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        statusPresenter = statusPresenterFactory?(monitor, processController)
        configureMenuBar()
        processController.onOperationChange = { [weak self] in
            guard let self else { return }
            self.statusPresenter?.update(self.monitor.snapshot)
            self.updateMenuItems()
        }
        monitor.onChange = { [weak self] snapshot in
            self?.processController.observe(snapshot)
            self?.statusPresenter?.update(snapshot)
            self?.statusItem?.button?.toolTip = snapshot.detail
            self?.updateMenuIcon(for: snapshot)
            self?.updateMenuItems()
        }
        monitor.start()
    }

    public func applicationWillTerminate(_ notification: Notification) {
        iconTimer?.invalidate()
        monitor.stop()
    }

    private func configureMenuBar() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let image = DeepSeekLogo.image(size: 18) {
            logoSource = image
        } else {
            item.button?.image = NSImage(systemSymbolName: "circle.grid.2x2.fill", accessibilityDescription: applicationName)
        }
        let menu = NSMenu()
        menu.delegate = self
        startMenuItem = menu.addItem(withTitle: "启动 DSH", action: #selector(startDSH), keyEquivalent: "")
        openMenuItem = menu.addItem(withTitle: "打开对话", action: #selector(openWeb), keyEquivalent: "")
        menu.addItem(.separator())
        quitDSHMenuItem = menu.addItem(withTitle: "安全退出 DSH…", action: #selector(quitDSH), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "打开 DSH 日志", action: #selector(openLog), keyEquivalent: "")
        loginItem = menu.addItem(withTitle: "开机自动启动", action: #selector(toggleLoginItem), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出 \(applicationName)", action: #selector(quitApp), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
        item.menu = menu
        statusItem = item
        updateMenuIcon(for: latestSnapshot)
        updateMenuItems()
    }

    public func menuWillOpen(_ menu: NSMenu) { updateMenuItems() }

    private func updateMenuItems() {
        let online = latestSnapshot.serverOnline
        startMenuItem?.isHidden = online
        startMenuItem?.title = processController.isStarting ? "正在启动…" : "启动 DSH"
        startMenuItem?.isEnabled = !processController.isStarting
        openMenuItem?.isHidden = !online
        openMenuItem?.isEnabled = online && !processController.isStopping
        quitDSHMenuItem?.isHidden = !online
        quitDSHMenuItem?.title = processController.isStopping ? "正在退出…" : "安全退出 DSH…"
        quitDSHMenuItem?.isEnabled = online && !processController.isStopping
        switch SMAppService.mainApp.status {
        case .enabled:
            loginItem?.state = .on
            loginItem?.title = "开机自动启动"
        case .requiresApproval:
            loginItem?.state = .mixed
            loginItem?.title = "开机自动启动（需系统确认）"
        default:
            loginItem?.state = .off
            loginItem?.title = "开机自动启动"
        }
    }

    private func updateMenuIcon(for snapshot: DSHSnapshot) {
        latestSnapshot = snapshot
        let animated = snapshot.light == .waiting || snapshot.light == .error
        if animated && iconTimer == nil {
            iconTimer = .scheduledTimer(withTimeInterval: 0.55, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.iconPhase.toggle()
                    self.applyMenuIcon()
                }
            }
        } else if !animated {
            iconTimer?.invalidate()
            iconTimer = nil
            iconPhase = true
        }
        applyMenuIcon()
    }

    private func applyMenuIcon() {
        guard let source = logoSource?.copy() as? NSImage else { return }
        source.size = NSSize(width: 18, height: 18)
        if latestSnapshot.light == .offline {
            source.isTemplate = true
            source.accessibilityDescription = latestSnapshot.detail
            statusItem?.button?.image = source
            statusItem?.button?.alphaValue = 1
            return
        }
        let color: NSColor
        switch latestSnapshot.light {
        case .offline: color = .white
        case .idle: color = .systemBlue
        case .working: color = .systemGreen
        case .waiting: color = .systemYellow
        case .error: color = .systemRed
        }
        let image = NSImage(size: source.size)
        image.lockFocus()
        source.draw(in: NSRect(origin: .zero, size: source.size))
        color.setFill()
        NSRect(origin: .zero, size: source.size).fill(using: .sourceAtop)
        image.unlockFocus()
        image.isTemplate = false
        image.accessibilityDescription = latestSnapshot.detail
        statusItem?.button?.image = image
        statusItem?.button?.alphaValue = (latestSnapshot.light == .waiting || latestSnapshot.light == .error) && !iconPhase ? 0.12 : 1
    }

    @objc private func startDSH() { processController.startDSH() }
    @objc private func openWeb() { processController.openWeb() }
    @objc private func quitDSH() { processController.requestSafeQuit() }
    @objc private func openLog() {
        do {
            let url = try DSHProcessController.ensureLogFile()
            NSWorkspace.shared.open(url)
        } catch {
            showAlert(title: "无法打开日志", message: error.localizedDescription)
        }
    }
    @objc private func toggleLoginItem() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
            updateMenuItems()
        } catch {
            showAlert(title: "无法更改登录启动设置", message: error.localizedDescription)
        }
    }
    @objc private func quitApp() { NSApp.terminate(nil) }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }
}
