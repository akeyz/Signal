import Cocoa

// MARK: - Light Color Definition

enum LightColor: String, CaseIterable {
    case black
    case red
    case yellow
    case green

    /// The NSColor used to draw the LED.
    var color: NSColor {
        switch self {
        case .black:
            let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark
                ? NSColor(srgbRed: 0.82, green: 0.82, blue: 0.82, alpha: 1.0)
                : NSColor(srgbRed: 0.25, green: 0.25, blue: 0.25, alpha: 1.0)
        case .red:    return NSColor(srgbRed: 0.882, green: 0.227, blue: 0.173, alpha: 1.0)
        case .yellow: return NSColor(srgbRed: 0.988, green: 0.753, blue: 0.075, alpha: 1.0)
        case .green:  return NSColor(srgbRed: 0.188, green: 0.635, blue: 0.310, alpha: 1.0)
        }
    }

    /// Full breathing cycle duration in seconds.
    /// Red = fastest, Yellow = medium, Green = slowest. Black does not breathe.
    var period: Double {
        switch self {
        case .black:  return 0
        case .red:    return 1.2
        case .yellow: return 2.4
        case .green:  return 4.0
        }
    }

    /// Whether the light breathes (animates).
    var breathes: Bool { self == .red || self == .yellow }

    /// Display label for the menu item.
    var label: String {
        switch self {
        case .black:
            let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark ? "⚪  Off" : "⚫  Off"
        case .red:    return "🔴  Red"
        case .yellow: return "🟡  Yellow"
        case .green:  return "🟢  Green"
        }
    }
}

// MARK: - Notification Name

extension NSNotification.Name {
    static let signalColorChange = NSNotification.Name("com.signal-light.colorChange")
    static let signalBreathToggle = NSNotification.Name("com.signal-light.toggleBreathing")
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var animationTimer: Timer?
    private var currentColor: LightColor = .black
    private var breathingEnabled: Bool = false
    private var phase: Double = 0.0

    // Animation update rate (~30 fps)
    private let fps: Double = 30.0

    /// Whether the timer should be running right now.
    private var needsTimer: Bool {
        breathingEnabled && currentColor.breathes
    }

    // MARK: Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.toolTip = "Signal – Status Light"

        buildMenu()
        updateAnimation()

        // Listen for color-change commands from sgl
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(didReceiveColorChange(_:)),
            name: .signalColorChange,
            object: nil
        )
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(didReceiveBreathToggle(_:)),
            name: .signalBreathToggle,
            object: nil
        )

        // Re-render when system appearance changes (light ↔ dark)
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(appearanceDidChange),
            name: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil
        )
    }

    @objc private func appearanceDidChange() {
        // Re-render static icon if no timer is running
        if animationTimer == nil {
            statusItem.button?.image = renderIcon()
        }
        buildMenu()
    }

    // MARK: Menu

    private func buildMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false

        // Title
        let titleItem = NSMenuItem(title: "Signal", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: NSColor.labelColor
        ]
        titleItem.attributedTitle = NSAttributedString(string: "Signal", attributes: attrs)
        menu.addItem(titleItem)

        menu.addItem(NSMenuItem.separator())

        // Color options
        for color in LightColor.allCases {
            let item = NSMenuItem(
                title: color.label,
                action: #selector(menuColorSelected(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = color
            item.state = (color == currentColor) ? .on : .off
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit Signal", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func menuColorSelected(_ sender: NSMenuItem) {
        guard let color = sender.representedObject as? LightColor else { return }
        switchColor(to: color)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: Color Switching

    private func switchColor(to newColor: LightColor) {
        guard newColor != currentColor else { return }
        currentColor = newColor
        phase = 0 // reset breathing cycle on switch
        buildMenu()
        updateAnimation()
    }

    @objc private func toggleBreathing() {
        breathingEnabled.toggle()
        phase = 0
        buildMenu()
        updateAnimation()
    }

    // MARK: Distributed Notification Handler

    @objc private func didReceiveColorChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let colorName = userInfo["color"] as? String,
              let color = LightColor(rawValue: colorName) else {
            return
        }
        DispatchQueue.main.async { [weak self] in
            self?.switchColor(to: color)
        }
    }

    @objc private func didReceiveBreathToggle(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let value = userInfo["enabled"] as? String else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let newValue = (value == "on")
            guard newValue != self.breathingEnabled else { return }
            self.toggleBreathing()
        }
    }

    // MARK: Animation

    /// Start or stop the timer based on whether animation is actually needed.
    private func updateAnimation() {
        if needsTimer {
            guard animationTimer == nil else { return }
            let interval = 1.0 / fps
            animationTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                self?.tick()
            }
            RunLoop.current.add(animationTimer!, forMode: .common)
        } else {
            animationTimer?.invalidate()
            animationTimer = nil
            // Render one static frame
            statusItem.button?.image = renderIcon()
        }
    }

    private func tick() {
        let dt = 1.0 / fps
        phase += (2.0 * .pi / currentColor.period) * dt
        if phase > 2.0 * .pi { phase -= 2.0 * .pi }

        statusItem.button?.image = renderIcon()
    }

    // MARK: Icon Rendering

    private func renderIcon() -> NSImage {
        let size = NSSize(width: 28, height: 28)
        let image = NSImage(size: size, flipped: false) { [self] rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let center = CGPoint(x: rect.midX, y: rect.midY)

            // Black = inert dark circle; Green = steady full; Red/Yellow = breathing
            if currentColor == .black {
                // Draw a plain dark circle and return early — no glow, no specular
                let baseColor = currentColor.color
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                baseColor.usingColorSpace(.sRGB)?.getRed(&r, green: &g, blue: &b, alpha: &a)
                let ledW: CGFloat = 8.0
                let ledH: CGFloat = 14.0
                let ledRect = CGRect(
                    x: center.x - ledW / 2, y: center.y - ledH / 2,
                    width: ledW, height: ledH
                )
                ctx.setFillColor(CGColor(srgbRed: r, green: g, blue: b, alpha: 1.0))
                let path = CGPath(roundedRect: ledRect, cornerWidth: 4.0, cornerHeight: 4.0, transform: nil)
                ctx.addPath(path)
                ctx.fillPath()
                // Subtle inner shadow for depth
                // let rimColor = CGColor(srgbRed: r * 0.9, green: g * 0.9, blue: b * 0.9, alpha: 1.0)
                // ctx.setStrokeColor(rimColor)
                // ctx.setLineWidth(0.8)
                // ctx.strokeEllipse(in: ledRect.insetBy(dx: 0.4, dy: 0.4))
                return true
            }

            let alpha: CGFloat
            if breathingEnabled && currentColor.breathes {
                let breath = CGFloat(0.5 + 0.5 * sin(phase - .pi / 2))
                alpha = 0.12 + 0.88 * breath
            } else {
                alpha = 1.0
            }

            // Extract sRGB components
            let baseColor = currentColor.color
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            baseColor.usingColorSpace(.sRGB)?.getRed(&r, green: &g, blue: &b, alpha: &a)

            // --- Layer 1: Soft outer glow (radial gradient) ---
            let glowRadius: CGFloat = 13.0
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let glowColors: [CGColor] = [
                CGColor(srgbRed: r, green: g, blue: b, alpha: alpha * 0.35),
                CGColor(srgbRed: r, green: g, blue: b, alpha: 0.0)
            ]
            if let gradient = CGGradient(
                colorsSpace: colorSpace,
                colors: glowColors as CFArray,
                locations: [0.0, 1.0]
            ) {
                ctx.drawRadialGradient(
                    gradient,
                    startCenter: center, startRadius: 4.0,
                    endCenter: center, endRadius: glowRadius,
                    options: []
                )
            }

            // --- Layer 2: Main LED rounded rect with 3D radial gradient ---
            let ledW: CGFloat = 8.0
            let ledH: CGFloat = 14.0
            let ledRect = CGRect(
                x: center.x - ledW / 2,
                y: center.y - ledH / 2,
                width: ledW,
                height: ledH
            )
            let path = CGPath(roundedRect: ledRect, cornerWidth: 4.0, cornerHeight: 4.0, transform: nil)

            // Brighter center, saturated edge
            let ledColors: [CGColor] = [
                CGColor(srgbRed: min(r + 0.35, 1.0), green: min(g + 0.35, 1.0), blue: min(b + 0.35, 1.0), alpha: alpha),
                CGColor(srgbRed: r, green: g, blue: b, alpha: alpha),
                CGColor(srgbRed: r * 0.55, green: g * 0.55, blue: b * 0.55, alpha: alpha)
            ]
            let ledLocations: [CGFloat] = [0.0, 0.55, 1.0]
            if let gradient = CGGradient(
                colorsSpace: colorSpace,
                colors: ledColors as CFArray,
                locations: ledLocations
            ) {
                ctx.saveGState()
                ctx.addPath(path)
                ctx.clip()
                // Offset highlight center slightly up-left for 3D feel
                let highlightCenter = CGPoint(x: center.x - 1.5, y: center.y + 2.0)
                ctx.drawRadialGradient(
                    gradient,
                    startCenter: highlightCenter, startRadius: 0,
                    endCenter: center, endRadius: 10.0,
                    options: [.drawsAfterEndLocation]
                )
                ctx.restoreGState()
            }

            // --- Layer 3: Specular highlight (small pill shape at the top) ---
            let specW: CGFloat = 4.0
            let specH: CGFloat = 2.5
            let specRect = CGRect(
                x: center.x - specW / 2,
                y: center.y + ledH / 2 - specH - 1.5,
                width: specW,
                height: specH
            )
            let specPath = CGPath(roundedRect: specRect, cornerWidth: 1.25, cornerHeight: 1.25, transform: nil)
            let specColor = CGColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: Double(alpha) * 0.55)
            ctx.setFillColor(specColor)
            ctx.addPath(specPath)
            ctx.fillPath()

            return true
        }

        image.isTemplate = false
        return image
    }
}
