import Foundation

/// Logic helpers for the session-complete screen. Pure, testable.
enum SessionCompleteLogic {

    private static let oneGB: Int64 = 1_073_741_824

    /// Returns true when storage freed is strictly greater than 1 GB.
    static func shouldShowConfetti(storageFreed: Int64) -> Bool {
        storageFreed > oneGB
    }

    /// Formats freed storage for the dopamine-hit display.
    static func freedDisplayText(bytes: Int64) -> String {
        SwipeFormatters.fileSize(bytes: bytes) + " freed"
    }
}
