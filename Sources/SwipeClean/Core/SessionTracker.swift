import Foundation
import Combine

/// Statistics for a single swipe session.
struct SessionStats {
    var photosReviewed: Int = 0
    var photosKept: Int = 0
    var photosDeleted: Int = 0
    var storageFreed: Int64 = 0
    var timeSpent: TimeInterval = 0
}

/// Lifetime aggregate statistics persisted to UserDefaults.
struct LifetimeStats {
    var totalPhotosReviewed: Int = 0
    var totalDeleted: Int = 0
    var totalStorageFreed: Int64 = 0
    var totalSessions: Int = 0
    var longestStreak: Int = 0
}

/// Tracks current session and persisted lifetime statistics.
final class SessionTracker: ObservableObject {

    // MARK: - Keys

    private enum Keys {
        static let totalReviewed = "sc_lifetime_reviewed"
        static let totalDeleted = "sc_lifetime_deleted"
        static let totalStorageFreed = "sc_lifetime_storage_freed"
        static let totalSessions = "sc_lifetime_sessions"
        static let longestStreak = "sc_lifetime_longest_streak"
    }

    // MARK: - Public State

    @Published private(set) var sessionStats = SessionStats()

    var lifetimeStats: LifetimeStats {
        LifetimeStats(
            totalPhotosReviewed: userDefaults.integer(forKey: Keys.totalReviewed),
            totalDeleted: userDefaults.integer(forKey: Keys.totalDeleted),
            totalStorageFreed: Int64(userDefaults.integer(forKey: Keys.totalStorageFreed)),
            totalSessions: userDefaults.integer(forKey: Keys.totalSessions),
            longestStreak: userDefaults.integer(forKey: Keys.longestStreak)
        )
    }

    // MARK: - Private

    private let userDefaults: UserDefaultsStoring
    private var sessionStartTime: Date?
    private var currentStreak: Int = 0

    // MARK: - Init

    init(userDefaults: UserDefaultsStoring = UserDefaults.standard) {
        self.userDefaults = userDefaults
    }

    // MARK: - Session Lifecycle

    func startSession() {
        sessionStats = SessionStats()
        sessionStartTime = Date()
        currentStreak = 0
    }

    func resetSession() {
        sessionStats = SessionStats()
        sessionStartTime = nil
        currentStreak = 0
    }

    /// Records a single photo review.
    /// - Parameters:
    ///   - kept: true if the user swiped right (keep), false for left (delete)
    ///   - fileSize: size in bytes of the reviewed photo
    func recordReview(kept: Bool, fileSize: Int64) {
        sessionStats.photosReviewed += 1

        if kept {
            sessionStats.photosKept += 1
            currentStreak = 0
        } else {
            sessionStats.photosDeleted += 1
            sessionStats.storageFreed += fileSize
            currentStreak += 1
        }

        // Update time spent
        if let start = sessionStartTime {
            sessionStats.timeSpent = Date().timeIntervalSince(start)
        }
    }

    /// Undoes the last delete record (called alongside DeleteManager.undo).
    func undoLastDelete(fileSize: Int64) {
        guard sessionStats.photosDeleted > 0 else { return }
        sessionStats.photosDeleted -= 1
        sessionStats.photosReviewed -= 1
        sessionStats.storageFreed -= fileSize
        currentStreak = max(0, currentStreak - 1)
    }

    /// Ends the session and persists stats to lifetime totals.
    func endSession() {
        // Update time
        if let start = sessionStartTime {
            sessionStats.timeSpent = Date().timeIntervalSince(start)
        }

        // Persist to lifetime
        let prevReviewed = userDefaults.integer(forKey: Keys.totalReviewed)
        userDefaults.set(prevReviewed + sessionStats.photosReviewed, forKey: Keys.totalReviewed)

        let prevDeleted = userDefaults.integer(forKey: Keys.totalDeleted)
        userDefaults.set(prevDeleted + sessionStats.photosDeleted, forKey: Keys.totalDeleted)

        let prevStorage = userDefaults.integer(forKey: Keys.totalStorageFreed)
        userDefaults.set(prevStorage + Int(sessionStats.storageFreed), forKey: Keys.totalStorageFreed)

        let prevSessions = userDefaults.integer(forKey: Keys.totalSessions)
        userDefaults.set(prevSessions + 1, forKey: Keys.totalSessions)

        let prevStreak = userDefaults.integer(forKey: Keys.longestStreak)
        if currentStreak > prevStreak {
            userDefaults.set(currentStreak, forKey: Keys.longestStreak)
        }
    }
}
