import AppKit
import TouchDSHCore
import TouchDSHShared

final class StatusLightView: NSView {
    var snapshot = DSHSnapshot(light: .offline, serverOnline: false) { didSet { needsDisplay = true } }
    private var phase = false
    private var animationTimer: Timer?
    private lazy var deepSeekLogoMask: NSImage? = makeDeepSeekLogo(size: 18)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        animationTimer = .scheduledTimer(withTimeInterval: 0.55, repeats: true) { [weak self] _ in
            self?.phase.toggle(); self?.needsDisplay = true
        }
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let bounds = self.bounds.insetBy(dx: 2, dy: 3)
        let path = NSBezierPath(roundedRect: bounds, xRadius: 7, yRadius: 7)
        NSColor(calibratedWhite: 0.11, alpha: 1).setFill(); path.fill()
        if snapshot.serverOnline {
            NSColor(calibratedRed: 0.16, green: 0.88, blue: 0.43, alpha: 0.95).setStroke()
            path.lineWidth = 1.5; path.stroke()
        }
        let logoColor: NSColor
        var alpha: CGFloat = 1
        switch snapshot.light {
        case .offline: logoColor = .white
        case .idle: logoColor = .systemBlue
        case .working: logoColor = .systemGreen
        case .waiting: logoColor = .systemYellow; alpha = phase ? 1 : 0.06
        case .error: logoColor = .systemRed; alpha = phase ? 1 : 0.05
        }
        if self.bounds.width <= 60 {
            drawLogo(in: NSRect(x: (self.bounds.width - 18) / 2, y: bounds.midY - 9, width: 18, height: 18),
                     color: logoColor, alpha: alpha)
        } else {
            drawLogo(in: NSRect(x: 12, y: bounds.midY - 9, width: 18, height: 18), color: logoColor, alpha: alpha)
            let text = NSAttributedString(string: expandedLabel, attributes: [
                .font: NSFont.systemFont(ofSize: 12, weight: .semibold), .foregroundColor: NSColor.white
            ])
            text.draw(at: NSPoint(x: 37, y: bounds.midY - 7))
        }
    }

    private var expandedLabel: String {
        let state: String
        switch snapshot.light {
        case .offline: state = "未启动"
        case .idle: state = "空闲"
        case .working: state = "工作中"
        case .waiting: state = "等待确认"
        case .error: state = "运行异常"
        }
        return "DeepSeek Harness · \(state)"
    }

    private func drawLogo(in rect: NSRect, color: NSColor, alpha: CGFloat) {
        guard let mask = deepSeekLogoMask else { return }
        let image = NSImage(size: rect.size)
        image.lockFocus()
        mask.draw(in: NSRect(origin: .zero, size: rect.size), from: .zero, operation: .sourceOver, fraction: 1)
        color.setFill()
        NSRect(origin: .zero, size: rect.size).fill(using: .sourceAtop)
        image.unlockFocus()
        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: alpha)
    }

    private func makeDeepSeekLogo(size side: CGFloat) -> NSImage? {
        guard let source = DeepSeekLogo.image(size: side) else { return nil }
        let size = NSSize(width: side, height: side)
        let image = NSImage(size: size)
        image.lockFocus()
        source.draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: .sourceOver, fraction: 1)
        NSColor.white.setFill()
        NSRect(origin: .zero, size: size).fill(using: .sourceAtop)
        image.unlockFocus()
        return image
    }
}

final class StatusLightButton: NSButton {
    static let preferredSize = NSSize(width: 55, height: 30)
    let lightView = StatusLightView(frame: .zero)

    override var intrinsicContentSize: NSSize { Self.preferredSize }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        isBordered = false
        title = ""
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
        addSubview(lightView)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func layout() { super.layout(); lightView.frame = bounds }
}
