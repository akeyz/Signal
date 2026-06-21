import Foundation

enum FlashMode: String, CaseIterable {
    case off
    case alertOnce
    case alertThree
    case continuous

    var label: String {
        switch self {
        case .off:
            return NSLocalizedString("Off", comment: "")
        case .alertOnce:
            return NSLocalizedString("1 Flash", comment: "")
        case .alertThree:
            return NSLocalizedString("3 Flashes", comment: "")
        case .continuous:
            return NSLocalizedString("Continuous", comment: "")
        }
    }
}
