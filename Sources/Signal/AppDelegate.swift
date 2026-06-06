import Cocoa
import ServiceManagement

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
                ? NSColor(srgbRed: 0.85, green: 0.85, blue: 0.85, alpha: 1.0)
                : NSColor(srgbRed: 0.10, green: 0.10, blue: 0.10, alpha: 1.0)
        case .red:    return NSColor(srgbRed: 0.882, green: 0.227, blue: 0.173, alpha: 1.0)
        case .yellow: return NSColor(srgbRed: 0.988, green: 0.753, blue: 0.075, alpha: 1.0)
        case .green:  return NSColor(srgbRed: 0.188, green: 0.635, blue: 0.310, alpha: 1.0)
        }
    }

    /// Full breathing cycle duration in seconds.
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
        let text: String
        switch self {
        case .black:  text = NSLocalizedString("Off", comment: "")
        case .red:    text = NSLocalizedString("Red", comment: "")
        case .yellow: text = NSLocalizedString("Yellow", comment: "")
        case .green:  text = NSLocalizedString("Green", comment: "")
        }

        switch self {
        case .black:
            let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark ? "⚪  \(text)" : "⚫  \(text)"
        case .red:    return "🔴  \(text)"
        case .yellow: return "🟡  \(text)"
        case .green:  return "🟢  \(text)"
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
    private var currentColor: LightColor = .black
    private var breathingEnabled: Bool = false

    // MARK: Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.toolTip = NSLocalizedString("Signal – Status Light", comment: "")

        buildMenu()
        applyIcon()

        // Listen for color-change commands from sgnl
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
        applyIcon()
        buildMenu()
    }

    // MARK: Menu

    private func buildMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false

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

        // Start at Login
        let startAtLoginItem = NSMenuItem(
            title: NSLocalizedString("Start at Login", comment: ""),
            action: #selector(toggleStartAtLogin(_:)),
            keyEquivalent: ""
        )
        startAtLoginItem.target = self
        startAtLoginItem.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
        menu.addItem(startAtLoginItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(
            title: NSLocalizedString("Quit Signal", comment: ""),
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func menuColorSelected(_ sender: NSMenuItem) {
        guard let color = sender.representedObject as? LightColor else { return }
        switchColor(to: color)
    }

    @objc private func toggleStartAtLogin(_ sender: NSMenuItem) {
        let service = SMAppService.mainApp
        if service.status == .enabled {
            do {
                try service.unregister()
                print("Successfully unregistered start at login")
            } catch {
                print("Failed to unregister start at login: \(error)")
            }
        } else {
            do {
                try service.register()
                print("Successfully registered start at login")
            } catch {
                print("Failed to register start at login: \(error)")
            }
        }
        buildMenu()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: Color Switching

    private func switchColor(to newColor: LightColor) {
        guard newColor != currentColor else { return }
        currentColor = newColor
        applyIcon()
        buildMenu()
    }

    @objc private func toggleBreathing() {
        breathingEnabled.toggle()
        applyIcon()
        buildMenu()
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

    // MARK: Icon & Animation

    /// Render the LED image, set it on the button, and start/stop breathing animation.
    private func applyIcon() {
        guard let button = statusItem.button else { return }
        button.wantsLayer = true
        button.image = renderLED()

        guard let buttonLayer = button.layer else { return }
        buttonLayer.removeAllAnimations()

        let shouldAnimate = breathingEnabled && currentColor.breathes
        if shouldAnimate {
            let anim = CABasicAnimation(keyPath: "opacity")
            anim.fromValue = 0.12
            anim.toValue = 1.0
            anim.duration = currentColor.period / 2.0
            anim.autoreverses = true
            anim.repeatCount = .infinity
            anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            buttonLayer.add(anim, forKey: "breathe")
        } else {
            buttonLayer.opacity = 1.0
        }
    }

    // MARK: Icon Rendering

    /// Render a static LED icon sized to fit the status bar without glow padding.
    private func renderLED() -> NSImage {
        let ledW: CGFloat = 8.0
        let ledH: CGFloat = 14.0
        let padding: CGFloat = 2.0
        let size = NSSize(width: ledW + padding * 2, height: ledH + padding * 2)
        let image = NSImage(size: size, flipped: false) { [self] rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let center = CGPoint(x: rect.midX, y: rect.midY)

            let baseColor = currentColor.color
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            baseColor.usingColorSpace(.sRGB)?.getRed(&r, green: &g, blue: &b, alpha: &a)

            let ledRect = CGRect(
                x: center.x - ledW / 2,
                y: center.y - ledH / 2,
                width: ledW,
                height: ledH
            )
            let path = CGPath(roundedRect: ledRect, cornerWidth: 4.0, cornerHeight: 4.0, transform: nil)

            if currentColor == .black {
                ctx.setFillColor(CGColor(srgbRed: r, green: g, blue: b, alpha: 1.0))
                ctx.addPath(path)
                ctx.fillPath()
                return true
            }

            // LED body with 3D gradient
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let ledColors: [CGColor] = [
                CGColor(srgbRed: min(r + 0.35, 1.0), green: min(g + 0.35, 1.0), blue: min(b + 0.35, 1.0), alpha: 1.0),
                CGColor(srgbRed: r, green: g, blue: b, alpha: 1.0),
                CGColor(srgbRed: r * 0.55, green: g * 0.55, blue: b * 0.55, alpha: 1.0)
            ]
            if let gradient = CGGradient(
                colorsSpace: colorSpace,
                colors: ledColors as CFArray,
                locations: [0.0, 0.55, 1.0]
            ) {
                ctx.saveGState()
                ctx.addPath(path)
                ctx.clip()
                let highlightCenter = CGPoint(x: center.x - 1.5, y: center.y + 2.0)
                ctx.drawRadialGradient(
                    gradient,
                    startCenter: highlightCenter, startRadius: 0,
                    endCenter: center, endRadius: 10.0,
                    options: [.drawsAfterEndLocation]
                )
                ctx.restoreGState()
            }

            // Specular highlight
            let specW: CGFloat = 4.0
            let specH: CGFloat = 2.5
            let specRect = CGRect(
                x: center.x - specW / 2,
                y: center.y + ledH / 2 - specH - 1.5,
                width: specW,
                height: specH
            )
            let specPath = CGPath(roundedRect: specRect, cornerWidth: 1.25, cornerHeight: 1.25, transform: nil)
            ctx.setFillColor(CGColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 0.55))
            ctx.addPath(specPath)
            ctx.fillPath()

            return true
        }
        image.isTemplate = false
        return image
    }
}
