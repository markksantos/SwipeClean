import Foundation

// MARK: - Swipe Direction

enum SwipeDirection: Equatable {
    case left
    case right
    case none
}

// MARK: - Swipe Gesture Calculator

/// Pure functions for all swipe gesture math. Fully testable, no SwiftUI dependency.
enum SwipeGestureCalculator {

    /// Determines swipe direction based on offset and velocity.
    /// - Velocity must exceed `velocityThreshold` AND match offset direction to trigger.
    /// - Offset must strictly exceed `threshold` to trigger.
    static func swipeDirection(
        offset: CGFloat,
        velocity: CGFloat,
        threshold: CGFloat,
        velocityThreshold: CGFloat
    ) -> SwipeDirection {
        // Velocity-based trigger: velocity exceeds threshold and direction matches offset
        if abs(velocity) > velocityThreshold {
            if velocity > 0 && offset > 0 {
                return .right
            } else if velocity < 0 && offset < 0 {
                return .left
            }
        }

        // Offset-based trigger: strictly exceeds threshold
        if offset > threshold {
            return .right
        } else if offset < -threshold {
            return .left
        }

        return .none
    }

    /// Rotation angle in degrees for a given horizontal offset.
    /// Formula: offset / 20, clamped to ±15°.
    static func rotation(for offset: CGFloat) -> CGFloat {
        let raw = offset / 20.0
        return min(max(raw, -15.0), 15.0)
    }

    /// Overlay opacity (0...0.7) proportional to swipe distance toward threshold.
    static func overlayOpacity(for offset: CGFloat, threshold: CGFloat) -> CGFloat {
        guard threshold > 0 else { return 0 }
        let progress = min(abs(offset) / threshold, 1.0)
        return progress * 0.7
    }

    /// Overlay scale (0.8...1.0) proportional to swipe distance toward threshold.
    static func overlayScale(for offset: CGFloat, threshold: CGFloat) -> CGFloat {
        guard threshold > 0 else { return 0.8 }
        let progress = min(abs(offset) / threshold, 1.0)
        return 0.8 + progress * 0.2
    }

    /// Whether the absolute offset exceeds the threshold.
    static func isPastThreshold(offset: CGFloat, threshold: CGFloat) -> Bool {
        abs(offset) > threshold
    }

    /// Horizontal destination for fly-off animation.
    static func flyOffOffset(direction: SwipeDirection) -> CGFloat {
        switch direction {
        case .right: return 500.0
        case .left: return -500.0
        case .none: return 0.0
        }
    }

    /// Rotation destination for fly-off animation.
    static func flyOffRotation(direction: SwipeDirection) -> CGFloat {
        switch direction {
        case .right: return 20.0
        case .left: return -20.0
        case .none: return 0.0
        }
    }
}
