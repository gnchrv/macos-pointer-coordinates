// PointerCoordinates
//
// A minimal macOS application that displays the current mouse pointer position
// on screen as a floating label that follows the cursor in real time.
//
// The label appears as a small "pill" (a rounded rectangle) just to the right
// and slightly below the cursor, showing coordinates in pixels (X, Y) where
// the origin (0, 0) is the top-left corner of the main screen.
//
// The app lives entirely in the menu bar — it has no dock icon or main window.

import AppKit  // AppKit is Apple's framework for building macOS user interfaces.
               // It provides everything needed to create windows, views, and respond
               // to system events on a Mac.


// MARK: - PillView

/// A rounded, frosted-glass panel that acts as the background for the coordinate label.
///
/// `PillView` inherits from `NSVisualEffectView`, which is a special macOS view
/// that can render a blurred, translucent background — the same "frosted glass"
/// effect you see in Control Centre, sidebars, and menus on macOS.
///
/// On top of the blur, a thin colour tint layer is applied to ensure the pill
/// looks right in both Light Mode and Dark Mode.
class PillView: NSVisualEffectView {

    /// A plain, transparent view used solely to apply a colour tint on top of the blur.
    ///
    /// Without this layer the frosted glass effect can look either too bright or too
    /// dark depending on the desktop wallpaper, so a semi-transparent white or black
    /// overlay is added to keep the contrast consistent.
    private let tint = NSView()

    /// Creates the pill with the given size and position on screen.
    ///
    /// `NSRect` describes a rectangle — here it defines where the pill sits and
    /// how big it is when first created. The actual size is updated every frame
    /// in `updateOverlay()` to fit the text.
    ///
    /// - Parameter frame: The initial rectangle (position + size) of this view.
    override init(frame: NSRect) {
        super.init(frame: frame)  // Always call super first when overriding init.

        // .contentBackground gives a subtle frosted-glass look, similar to
        // the background of a popover or panel on macOS.
        material = .contentBackground

        // .behindWindow means the blur samples pixels from whatever is behind
        // the overlay window (e.g. other apps, the desktop), not just from
        // content inside our own app.
        blendingMode = .behindWindow

        // .active keeps the effect always visible, even when the app is not
        // in the foreground (which it never is, since it has no main window).
        state = .active

        // wantsLayer = true tells AppKit that this view should be backed by a
        // Core Animation layer. Layers are necessary for corner rounding,
        // opacity animations, and other GPU-accelerated effects.
        wantsLayer = true

        // Round the corners to produce the "pill" shape.
        // cornerRadius is measured in points (roughly pixels on a standard display).
        layer?.cornerRadius = 6

        // Clip any child content that extends outside the rounded corners,
        // so the tint overlay also gets rounded edges.
        layer?.masksToBounds = true

        // Allow the tint view to resize automatically when its parent resizes.
        // .width and .height mean "stretch with the parent in both directions".
        tint.autoresizingMask = [.width, .height]

        // wantsLayer = true on the tint view so we can set a background colour
        // on its Core Animation layer (plain NSViews have no background by default).
        tint.wantsLayer = true

        // Place the tint view inside the pill, behind any future subviews.
        addSubview(tint)

        // Apply the correct tint colour for the current appearance (Light / Dark).
        updateTint()
    }

    /// Required by Swift/AppKit when loading views from Interface Builder (`.xib` / `.storyboard` files).
    /// This app does not use Interface Builder, so this path is never taken and we crash intentionally
    /// to catch mistakes during development.
    required init?(coder: NSCoder) { fatalError() }

    /// Called automatically by AppKit whenever the system appearance changes —
    /// for example when the user switches between Light Mode and Dark Mode in
    /// System Settings, or when macOS applies auto-switching at sunrise/sunset.
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateTint()  // Re-apply the tint so it stays correct for the new appearance.
    }

    /// Decides whether the current appearance is Dark Mode, then applies an appropriate
    /// semi-transparent tint layer on top of the blurred background.
    ///
    /// In Dark Mode a faint black tint is used to deepen the already-dark background.
    /// In Light Mode a stronger white tint is used to brighten and opacify the surface,
    /// preventing the label text from blending into colourful wallpapers.
    private func updateTint() {
        // `effectiveAppearance` reflects the actual appearance in use at this moment,
        // taking into account system-wide settings and any overrides on parent views.
        // `.bestMatch(from:)` returns whichever named appearance from the list most
        // closely matches the current look. We compare against the two standard variants:
        //   .aqua      — the standard Light Mode appearance
        //   .darkAqua  — the standard Dark Mode appearance
        let isDark = effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua

        // Make the tint fill the entire pill exactly.
        tint.frame = bounds

        // Set the tint colour on the Core Animation layer.
        // `NSColor` describes a colour; `.cgColor` converts it to the format that
        // Core Animation layers understand. The `alpha` parameter controls opacity:
        // 0.0 = fully transparent, 1.0 = fully opaque.
        tint.layer?.backgroundColor = isDark
            ? NSColor(white: 0, alpha: 0.10).cgColor   // Black at 10 % opacity for Dark Mode.
            : NSColor(white: 1, alpha: 0.72).cgColor   // White at 72 % opacity for Light Mode.
    }
}

// MARK: - PillView Extension

extension PillView {

    /// Resizes the tint overlay to match a new pill size.
    ///
    /// Called from `updateOverlay()` every frame after the pill dimensions change
    /// to fit the updated coordinate text. Because `autoresizingMask` handles most
    /// automatic resizing, this method only needs to handle the tint's frame directly
    /// when the pill's size is set programmatically (bypassing the normal layout pass).
    ///
    /// - Parameters:
    ///   - w: The new width of the pill in points.
    ///   - h: The new height of the pill in points.
    func updateTintFrame(_ w: CGFloat, _ h: CGFloat) {
        // `NSRect(x:y:width:height:)` creates a rectangle positioned at (0, 0) relative
        // to the pill's own coordinate system, filling the full width and height.
        tint.frame = NSRect(x: 0, y: 0, width: w, height: h)
    }
}


// MARK: - AppDelegate

/// The central coordinator for the application.
///
/// On macOS, every application must have a *delegate* — an object that AppKit
/// calls when important lifecycle events happen, such as the app finishing its
/// launch sequence. `AppDelegate` conforms to `NSApplicationDelegate` to receive
/// those events.
///
/// This class is responsible for:
/// - Creating the menu-bar icon with a Quit option.
/// - Creating the floating overlay panel that follows the cursor.
/// - Running a high-frequency timer that reads the pointer position and updates the overlay.
class AppDelegate: NSObject, NSApplicationDelegate {

    /// The small icon that appears in the macOS menu bar (the strip at the very top of the screen).
    /// Holding an `NSStatusItem` keeps it visible for as long as the app is running.
    var statusItem: NSStatusItem?

    /// The transparent, borderless floating window that contains the pill and label.
    /// `NSPanel` is a lightweight window type designed for auxiliary UI like palettes and HUDs.
    var overlayWindow: NSPanel?

    /// The text field that displays the current X, Y coordinates.
    var label: NSTextField?

    /// The frosted-glass pill view that acts as the visual background for the label.
    var pill: PillView?

    /// The repeating timer that reads the mouse position and redraws the overlay roughly 60 times per second.
    var timer: Timer?


    // MARK: App Lifecycle

    /// Called by AppKit once the application has fully started and is ready to run.
    ///
    /// This is the entry point for our setup code — think of it as the macOS equivalent
    /// of a program's `main()` function, but triggered after the system has initialised
    /// all the low-level infrastructure our app depends on.
    ///
    /// - Parameter notification: System-provided context about the launch event (unused here).
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()   // Add the menu-bar icon.
        setupOverlay()   // Create the floating coordinate window.

        // Create a timer that fires every 0.016 seconds (≈ 60 times per second,
        // matching the typical screen refresh rate) and calls `updateOverlay`
        // each time. The `[weak self]` prevents a memory leak by not keeping a
        // strong reference to `AppDelegate` inside the closure.
        timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            self?.updateOverlay()
        }

        // By default, scheduled timers pause when the app is tracking mouse events
        // (e.g. during a drag). Adding it to `.common` mode keeps it firing even then,
        // which is essential because we want to track the pointer during drags too.
        RunLoop.main.add(timer!, forMode: .common)
    }


    // MARK: Setup

    /// Adds a cursor icon to the macOS menu bar and attaches a minimal drop-down menu.
    ///
    /// `NSStatusBar.system` is the global object that manages all menu-bar items.
    /// `squareLength` gives the item a standard square width so the icon fits neatly
    /// between other menu-bar icons.
    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        // Set the icon using a built-in SF Symbol. SF Symbols is Apple's icon library;
        // "cursorarrow" is the standard arrow cursor symbol. The `accessibilityDescription`
        // is read aloud by VoiceOver for users who rely on assistive technology.
        statusItem?.button?.image = NSImage(
            systemSymbolName: "cursorarrow",
            accessibilityDescription: "Pointer Coordinates"
        )

        // Build a drop-down menu with a single item: Quit.
        // `NSApplication.terminate(_:)` is the standard macOS action that cleanly
        // shuts the app down. The key equivalent "q" means the user can also press
        // ⌘Q while the menu is open to quit.
        let menu = NSMenu()
        menu.addItem(NSMenuItem(
            title: "Quit",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
        statusItem?.menu = menu
    }

    /// Creates and shows the transparent floating window that displays the coordinates.
    ///
    /// The window is intentionally designed to be completely invisible to the user
    /// as a traditional window — it has no title bar, no shadow, and cannot be clicked.
    /// It exists purely to host the pill view in a layer above all other applications.
    func setupOverlay() {
        // Create an NSPanel — a lighter alternative to NSWindow suited for
        // tool palettes and auxiliary overlays.
        //
        // contentRect: The initial rectangle. Position (0, 0) and size (200 × 28)
        //              are placeholder values; `updateOverlay()` repositions it
        //              every frame anyway.
        //
        // styleMask:   .borderless removes the title bar and window chrome entirely.
        //              .nonactivatingPanel means clicking in this panel will NOT
        //              steal keyboard focus from whatever app the user is working in.
        //
        // backing:     .buffered means the window draws into an off-screen buffer
        //              first, then blits it to the screen — the standard approach
        //              for flicker-free rendering.
        //
        // defer:       false means the underlying window is created immediately
        //              rather than lazily on first display.
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 28),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // .screenSaver level places the panel above almost everything on screen,
        // including full-screen apps and the menu bar. This ensures the overlay
        // is always visible regardless of what the user is doing.
        panel.level = .screenSaver

        // Make the window's background fully transparent so only the pill is visible.
        panel.backgroundColor = .clear
        panel.isOpaque = false

        // Prevent the overlay from intercepting any mouse clicks or drags.
        // Without this, the user would not be able to click through the overlay
        // onto whatever is beneath it.
        panel.ignoresMouseEvents = true

        // collectionBehavior controls how the window behaves across macOS Spaces
        // (virtual desktops) and full-screen mode:
        //   .canJoinAllSpaces  — the panel appears on every Space simultaneously.
        //   .stationary        — the panel does not move when the user switches Spaces.
        //   .fullScreenAuxiliary — the panel can appear alongside full-screen apps.
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

        // Remove the drop shadow that macOS adds to panels by default.
        // A shadow beneath a transparent window would look like a floating rectangle.
        panel.hasShadow = false

        // Create the frosted-glass pill view and place it at the panel's origin.
        let container = PillView(frame: NSRect(x: 0, y: 0, width: 200, height: 28))

        // Create the text label that will display "X, Y" coordinates.
        // The frame positions it 8 points from the left edge and 5 points from
        // the bottom of the pill, with a little room on the right.
        let lbl = NSTextField(frame: NSRect(x: 8, y: 5, width: 184, height: 18))

        lbl.isBezeled = false       // Remove the border that text fields normally have.
        lbl.isEditable = false      // Prevent the user from typing into this field.
        lbl.drawsBackground = false // Do not draw a white background behind the text.
        lbl.textColor = .labelColor // Use the system's adaptive text colour — dark in
                                    // Light Mode, light in Dark Mode — for readability.

        // Use a monospaced font so every digit has the same width.
        // This stops the pill from visibly resizing each time a digit changes width
        // (e.g. from "9" to "10"), keeping the display stable while the cursor moves.
        lbl.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)

        lbl.alignment = .left  // Align the coordinate text to the left edge.

        // Assemble the view hierarchy:
        //   panel → contentView → container (pill) → lbl (coordinate label)
        container.addSubview(lbl)
        panel.contentView?.addSubview(container)

        // Show the panel on screen. `nil` means "use the default ordering position",
        // which places it in front of other windows at the same level.
        panel.orderFront(nil)

        // Store references so other methods can access these objects later.
        overlayWindow = panel
        label = lbl
        pill = container
    }


    // MARK: Per-Frame Update

    /// Reads the current mouse pointer position, converts it to screen coordinates,
    /// and repositions the overlay pill to follow the cursor.
    ///
    /// This method is called approximately 60 times per second by the repeating timer.
    ///
    /// **Coordinate system note:** macOS normally places the origin (0, 0) at the
    /// *bottom-left* corner of the screen and counts upwards — the opposite of most
    /// graphics systems. This method converts that to a top-left origin so the Y value
    /// shown to the user matches what design tools and CSS typically display.
    func updateOverlay() {
        // `NSEvent.mouseLocation` returns the cursor position in macOS's native
        // coordinate system: (0, 0) at the bottom-left of the main screen,
        // Y increasing upwards. Units are points (equivalent to pixels on
        // non-Retina displays; each point is 2 physical pixels on Retina).
        let mouse = NSEvent.mouseLocation

        // Exit early if no screen is available (unlikely but defensive).
        guard let screen = NSScreen.main else { return }

        // Convert X: no change needed — horizontal position is already correct.
        // `.rounded()` snaps the sub-pixel value to the nearest whole number.
        // `Int(...)` converts the floating-point result to an integer for a clean display.
        let x = Int(mouse.x.rounded())

        // Convert Y: macOS counts from the bottom, but users expect 0 at the top.
        // Subtracting the cursor's Y from the total screen height flips the axis.
        let y = Int((screen.frame.height - mouse.y).rounded())

        // Update the label text to show the current coordinates.
        label?.stringValue = "\(x), \(y)"

        // Resize the label's frame to exactly fit the new text.
        // Because the number of digits can change (e.g. "99" vs "1024"),
        // the pill width must be recalculated every frame.
        label?.sizeToFit()

        // Add horizontal padding on both sides of the text.
        let padding: CGFloat = 10

        // Read the label's new width after `sizeToFit()` recalculated it.
        let textWidth = label?.frame.width ?? 0

        // The pill is as wide as the text plus the total horizontal padding.
        let pillWidth = textWidth + padding

        // Fixed pill height — tall enough for a 12 pt font with a little breathing room.
        let pillHeight: CGFloat = 22

        // Resize the pill to fit the text exactly.
        pill?.frame = NSRect(x: 0, y: 0, width: pillWidth, height: pillHeight)

        // Also resize the tint overlay inside the pill (the blur layer does not
        // update its child views automatically when set programmatically).
        pill?.updateTintFrame(pillWidth, pillHeight)

        // Reposition the label within the (now-resized) pill so it is centred vertically
        // and starts at half the padding from the left edge.
        label?.frame = NSRect(
            x: padding / 2,                                          // Horizontal offset from pill's left edge.
            y: (pillHeight - (label?.frame.height ?? 0)) / 2,       // Vertical centre within the pill.
            width: textWidth,
            height: label?.frame.height ?? 0
        )

        // Resize the window itself to match the pill.
        overlayWindow?.setContentSize(NSSize(width: pillWidth, height: pillHeight))

        // Position the overlay window relative to the mouse cursor.
        // The offset nudges the pill slightly to the right and downward so it sits
        // neatly beside the cursor tip rather than directly underneath it.
        let offsetX: CGFloat = 14   // Points to the right of the cursor.
        let offsetY: CGFloat = -22  // Points below the cursor (negative = downward in macOS coords).
        overlayWindow?.setFrameOrigin(NSPoint(x: mouse.x + offsetX, y: mouse.y + offsetY))
    }


    // MARK: Cleanup

    /// Called when the `AppDelegate` object is removed from memory.
    ///
    /// Invalidating the timer here stops it from firing after the delegate is gone,
    /// which would otherwise cause a crash because the timer would try to call
    /// `updateOverlay()` on a deallocated object.
    deinit {
        timer?.invalidate()
    }
}


// MARK: - Application Entry Point

// Every macOS app needs a single shared `NSApplication` instance.
// `NSApplication.shared` creates (or returns) that singleton.
let app = NSApplication.shared

// `.accessory` policy hides the app from the Dock and the App Switcher (⌘Tab).
// The app is accessible only through its menu-bar icon.
app.setActivationPolicy(.accessory)

// Create the delegate and hand it to the application. AppKit will call
// `applicationDidFinishLaunching(_:)` on this object once the app is ready.
let delegate = AppDelegate()
app.delegate = delegate

// Start the application's run loop — this call blocks indefinitely, processing
// system events (mouse moves, screen changes, menu interactions, etc.) until
// the user chooses Quit. Everything from this point onwards is event-driven.
app.run()
