import Foundation

/// Layout constants for the card stack. Pure struct, testable.
enum CardStackLayout {

    static let maxVisibleCards = 3

    /// Scale factor for a card at the given stack index (0 = front).
    static func scale(forIndex index: Int) -> CGFloat {
        switch index {
        case 0: return 1.0
        case 1: return 0.95
        case 2: return 0.90
        default: return 0.90
        }
    }

    /// Vertical offset in points for a card at the given stack index (0 = front).
    static func yOffset(forIndex index: Int) -> CGFloat {
        switch index {
        case 0: return 0.0
        case 1: return 8.0
        case 2: return 16.0
        default: return 16.0
        }
    }
}
