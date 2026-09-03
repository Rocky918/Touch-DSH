import AppKit
import TouchDSHCore
import TouchDSHShared
import TouchBarPrivate

@MainActor
final class TouchBarController: NSObject, NSTouchBarDelegate, DSHStatusPresenting {
    static let controlID = NSTouchBarItem.Identifier("app.touchdsh.touchbar.control-strip")
    private let monitor: DSHMonitor
    private let processController: DSHProcessController
    private let touchBar = NSTouchBar()
    private let stripButton = StatusLightButton(frame: NSRect(origin: .zero, size: StatusLightButton.preferredSize))
    private let fullStatus = StatusLightView(frame: NSRect(x: 0, y: 0, width: 225, height: 30))
    private var controlStripItem: NSCustomTouchBarItem?
    private var fullStatusItem: NSCustomTouchBarItem?
    private var visibleIdentifiers: [NSTouchBarItem.Identifier] = []

    init(monitor: DSHMonitor, processController: DSHProcessController) {
        self.monitor = monitor; self.processController = processController
        super.init()
        configure()
    }

    private func configure() {
        touchBar.delegate = self
        stripButton.widthAnchor.constraint(equalToConstant: StatusLightButton.preferredSize.width).isActive = true
        stripButton.heightAnchor.constraint(equalToConstant: StatusLightButton.preferredSize.height).isActive = true
        fullStatus.widthAnchor.constraint(equalToConstant: 225).isActive = true
        fullStatus.heightAnchor.constraint(equalToConstant: 30).isActive = true
        stripButton.target = self; stripButton.action = #selector(present)
        stripButton.toolTip = "打开 DSH 控制条"
        monitor.onChange = { [weak self] snapshot in self?.update(snapshot) }
        processController.onOperationChange = { [weak self] in
            guard let self else { return }
            self.update(self.monitor.snapshot)
        }
        update(monitor.snapshot)
        guard TBPrivateAvailable() else { return }
        TBSetShowsCloseBox(false)
        let item = NSCustomTouchBarItem(identifier: Self.controlID)
        item.visibilityPriority = NSTouchBarItem.Priority(rawValue: 10_000)
        item.customizationLabel = "Touch DSH"
        item.view = stripButton
        controlStripItem = item
        TBAddSystemTrayItem(item)
        TBSetControlStripPresence(Self.controlID, true)
    }

    func update(_ snapshot: DSHSnapshot) {
        stripButton.lightView.snapshot = snapshot
        fullStatus.snapshot = snapshot
        fullStatus.toolTip = snapshot.detail
        let actions: [NSTouchBarItem.Identifier]
        if processController.isStarting {
            actions = [.starting]
        } else if snapshot.serverOnline {
            actions = processController.isStopping ? [.stopping] : [.open, .power]
        } else {
            actions = [.start]
        }
        let next: [NSTouchBarItem.Identifier] = [.status, .flexibleSpace] + actions + [.close]
        guard next != visibleIdentifiers else { return }
        visibleIdentifiers = next
        touchBar.defaultItemIdentifiers = next
    }

    @objc private func present() { _ = TBPresentSystemModal(touchBar, Self.controlID) }
    @objc private func minimize() {
        TBMinimizeSystemModal(touchBar)
        restoreControlStripPresence()
    }
    @objc private func start() { processController.startDSH() }
    @objc private func open() { processController.openWeb() }
    @objc private func quitDSH() { processController.requestSafeQuit() }

    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        let item = NSCustomTouchBarItem(identifier: identifier)
        switch identifier {
        case .status:
            fullStatus.toolTip = monitor.snapshot.detail
            item.view = fullStatus
            fullStatusItem = item
        case .start:
            item.view = button(title: "启动 DSH", symbol: "play.fill", action: #selector(start))
        case .starting:
            let button = NSButton(title: "正在启动…", target: nil, action: nil)
            button.image = NSImage(systemSymbolName: "hourglass", accessibilityDescription: "正在启动 DSH")
            button.imagePosition = .imageLeading
            button.isEnabled = false
            item.view = button
        case .open:
            item.view = button(title: "打开对话", symbol: "safari", action: #selector(open))
        case .power:
            let button = NSButton(title: "退出 DSH", target: self, action: #selector(quitDSH))
            button.image = NSImage(systemSymbolName: "power", accessibilityDescription: "彻底退出 DSH")
            button.imagePosition = .imageLeading
            button.bezelColor = .systemRed
            item.view = button
        case .stopping:
            let button = NSButton(title: "正在退出…", target: nil, action: nil)
            button.image = NSImage(systemSymbolName: "hourglass", accessibilityDescription: "正在退出 DSH")
            button.imagePosition = .imageLeading
            button.isEnabled = false
            item.view = button
        case .close:
            item.view = button(title: "收起", symbol: "chevron.right", action: #selector(minimize))
        default: return nil
        }
        return item
    }

    private func button(title: String, symbol: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        button.imagePosition = .imageLeading
        return button
    }

    private func restoreControlStripPresence() {
        guard controlStripItem != nil else { return }
        TBSetControlStripPresence(Self.controlID, true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard self?.controlStripItem != nil else { return }
            TBSetControlStripPresence(Self.controlID, true)
        }
    }
}

private extension NSTouchBarItem.Identifier {
    static let status = Self("app.touchdsh.touchbar.status")
    static let start = Self("app.touchdsh.touchbar.start")
    static let starting = Self("app.touchdsh.touchbar.starting")
    static let open = Self("app.touchdsh.touchbar.open")
    static let power = Self("app.touchdsh.touchbar.power")
    static let stopping = Self("app.touchdsh.touchbar.stopping")
    static let close = Self("app.touchdsh.touchbar.close")
}
