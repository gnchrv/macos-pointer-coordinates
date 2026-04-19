import AppKit

class PillView: NSVisualEffectView {
    private let tint = NSView()

    override init(frame: NSRect) {
        super.init(frame: frame)
        material = .contentBackground
        blendingMode = .behindWindow
        state = .active
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.masksToBounds = true

        tint.wantsLayer = true
        tint.autoresizingMask = [.width, .height]
        addSubview(tint)
        updateTint()
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateTint()
    }

    private func updateTint() {
        let isDark = effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        tint.frame = bounds
        tint.layer?.backgroundColor = isDark
            ? NSColor(white: 0, alpha: 0.1).cgColor
            : NSColor(white: 1, alpha: 0.72).cgColor
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var overlayWindow: NSPanel?
    var label: NSTextField?
    var pill: PillView?
    var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupOverlay()

        timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            self?.updateOverlay()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem?.button?.image = NSImage(systemSymbolName: "cursorarrow", accessibilityDescription: "Pointer Coordinates")

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    func setupOverlay() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 28),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .screenSaver
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.hasShadow = false

        let container = PillView(frame: NSRect(x: 0, y: 0, width: 200, height: 28))

        let lbl = NSTextField(frame: NSRect(x: 8, y: 5, width: 184, height: 18))
        lbl.isBezeled = false
        lbl.isEditable = false
        lbl.drawsBackground = false
        lbl.textColor = .labelColor
        lbl.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        lbl.alignment = .left

        container.addSubview(lbl)
        panel.contentView?.addSubview(container)
        panel.orderFront(nil)

        overlayWindow = panel
        label = lbl
        pill = container
    }

    func updateOverlay() {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.main else { return }

        let x = Int(mouse.x.rounded())
        let y = Int((screen.frame.height - mouse.y).rounded())
        label?.stringValue = "\(x), \(y)"
        label?.sizeToFit()

        let padding: CGFloat = 10
        let textWidth = label?.frame.width ?? 0
        let pillWidth = textWidth + padding
        let pillHeight: CGFloat = 22

        pill?.frame = NSRect(x: 0, y: 0, width: pillWidth, height: pillHeight)
        pill?.updateTintFrame(pillWidth, pillHeight)
        label?.frame = NSRect(x: padding / 2, y: (pillHeight - (label?.frame.height ?? 0)) / 2,
                              width: textWidth, height: label?.frame.height ?? 0)

        overlayWindow?.setContentSize(NSSize(width: pillWidth, height: pillHeight))

        let offsetX: CGFloat = 14
        let offsetY: CGFloat = -22
        overlayWindow?.setFrameOrigin(NSPoint(x: mouse.x + offsetX, y: mouse.y + offsetY))
    }

    deinit {
        timer?.invalidate()
    }
}

extension PillView {
    func updateTintFrame(_ w: CGFloat, _ h: CGFloat) {
        tint.frame = NSRect(x: 0, y: 0, width: w, height: h)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
