import Cocoa
import ServiceManagement
import SwiftUI


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
    
    private let viewModel = AppViewModel()
    private var popover: NSPopover!

    // MARK: Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.toolTip = NSLocalizedString("Signal – Status Light", comment: "")

        applyIcon()
        setupPopover()

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
    }

    // MARK: Popover Setup

    private func setupPopover() {
        popover = NSPopover()
        popover.behavior = .transient
        
        let hostingController = NSHostingController(rootView: MainView(viewModel: viewModel))
        hostingController.preferredContentSize = NSSize(width: 350, height: 480)
        
        popover.contentViewController = hostingController
        popover.contentSize = NSSize(width: 350, height: 480)
        
        // Link status item action to toggle popover
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover(_:))
        }
        
        // Configure AppViewModel state & callbacks
        viewModel.currentColor = currentColor
        viewModel.breathingEnabled = breathingEnabled
        viewModel.refreshStartAtLogin()
        
        viewModel.onColorChange = { [weak self] color in
            self?.switchColor(to: color)
        }
        viewModel.onBreathingChange = { [weak self] enabled in
            guard let self = self else { return }
            if self.breathingEnabled != enabled {
                self.toggleBreathing()
            }
        }
        viewModel.onStartAtLoginChange = { [weak self] enabled in
            self?.setStartAtLogin(enabled)
        }
        viewModel.onInstallCLI = { [weak self] in
            self?.installCLI()
        }
        viewModel.onQuit = {
            NSApp.terminate(nil)
        }
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.close()
        } else {
            // Refresh state before showing popover
            viewModel.currentColor = currentColor
            viewModel.breathingEnabled = breathingEnabled
            viewModel.refreshStartAtLogin()
            
            popover.contentSize = NSSize(width: 350, height: 480)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func setStartAtLogin(_ enabled: Bool) {
        let service = SMAppService.mainApp
        if enabled {
            do {
                try service.register()
                print("Successfully registered start at login")
            } catch {
                print("Failed to register start at login: \(error)")
            }
        } else {
            do {
                try service.unregister()
                print("Successfully unregistered start at login")
            } catch {
                print("Failed to unregister start at login: \(error)")
            }
        }
        viewModel.refreshStartAtLogin()
    }

    private func installCLI() {
        let fileManager = FileManager.default
        let homeDir = fileManager.homeDirectoryForCurrentUser
        let targetDir = homeDir.appendingPathComponent("local/bin")
        let targetURL = targetDir.appendingPathComponent("sgnl")
        
        guard let sourceURL = Bundle.main.url(forResource: "sgnl", withExtension: nil) else {
            showCLIError(message: "Could not locate the 'sgnl' binary inside the application bundle resources.")
            return
        }
        
        do {
            // Create target folder if it doesn't exist
            if !fileManager.fileExists(atPath: targetDir.path) {
                try fileManager.createDirectory(at: targetDir, withIntermediateDirectories: true, attributes: nil)
            }
            
            // Remove existing CLI if it's there
            if fileManager.fileExists(atPath: targetURL.path) {
                try fileManager.removeItem(at: targetURL)
            }
            
            // Copy new CLI
            try fileManager.copyItem(at: sourceURL, to: targetURL)
            
            // Make executable (chmod +x)
            chmod(targetURL.path, 0o755)
            
            // Show success alert
            let alert = NSAlert()
            alert.messageText = "Installation Successful"
            alert.informativeText = "The 'sgnl' command-line tool has been installed to:\n\(targetURL.path)\n\nPlease make sure '\(targetDir.path)' is in your PATH."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
            
        } catch {
            showCLIError(message: "An error occurred during installation:\n\(error.localizedDescription)")
        }
    }
    
    private func showCLIError(message: String) {
        let alert = NSAlert()
        alert.messageText = "Installation Failed"
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    // MARK: Color Switching

    private func switchColor(to newColor: LightColor) {
        guard newColor != currentColor else { return }
        currentColor = newColor
        viewModel.currentColor = newColor
        applyIcon()
    }

    @objc private func toggleBreathing() {
        breathingEnabled.toggle()
        viewModel.breathingEnabled = breathingEnabled
        applyIcon()
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
        let ledH: CGFloat = 16.0
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
