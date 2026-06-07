import Cocoa

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
