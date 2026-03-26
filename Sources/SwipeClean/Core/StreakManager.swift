import Foundation
import Combine

/// Manages daily streak tracking — consecutive days with at least one swipe session.
final class StreakManager: ObservableObject {

    // MARK: - Keys

    private enum Keys {
        static let currentStreak = "sc_streak_current"
        static let bestStreak = "sc_streak_best"
        static let lastActiveDate = "sc_streak_last_active"
    }

    // MARK: - Published State

    @Published private(set) var currentStreak: Int = 0
    @Published private(set) var bestStreak: Int = 0

    // MARK: - Private

    private let userDefaults: UserDefaultsStoring
    private let calendar: Calendar

    // MARK: - Init

    init(userDefaults: UserDefaultsStoring = UserDefaults.standard, calendar: Calendar = .current) {
        self.userDefaults = userDefaults
        self.calendar = calendar
        loadStreak()
    }

    // MARK: - Public

    /// Call when the user completes a swipe session. Updates the daily streak.
    func recordSession() {
        let today = calendar.startOfDay(for: Date())

        if let lastActiveRaw = userDefaults.object(forKey: Keys.lastActiveDate) as? Date {
            let lastActive = calendar.startOfDay(for: lastActiveRaw)

            if lastActive == today {
                // Already recorded today — no change
                return
            }

            let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
            if lastActive == yesterday {
                // Consecutive day — increment streak
                currentStreak += 1
            } else {
                // Streak broken — reset to 1
                currentStreak = 1
            }
        } else {
            // First ever session
            currentStreak = 1
        }

        // Update best streak
        if currentStreak > bestStreak {
            bestStreak = currentStreak
        }

        // Persist
        userDefaults.set(currentStreak, forKey: Keys.currentStreak)
        userDefaults.set(bestStreak, forKey: Keys.bestStreak)
        userDefaults.set(today as Any, forKey: Keys.lastActiveDate)
    }

    /// Resets all streak data. Called when the user resets statistics.
    func resetStreak() {
        currentStreak = 0
        bestStreak = 0
        userDefaults.set(0, forKey: Keys.currentStreak)
        userDefaults.set(0, forKey: Keys.bestStreak)
        userDefaults.set(nil, forKey: Keys.lastActiveDate)
    }

    // MARK: - Private

    private func loadStreak() {
        let savedStreak = userDefaults.integer(forKey: Keys.currentStreak)
        bestStreak = userDefaults.integer(forKey: Keys.bestStreak)

        // Validate streak is still active (not broken since last launch)
        if let lastActiveRaw = userDefaults.object(forKey: Keys.lastActiveDate) as? Date {
            let today = calendar.startOfDay(for: Date())
            let lastActive = calendar.startOfDay(for: lastActiveRaw)
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

            if lastActive == today || lastActive == yesterday {
                currentStreak = savedStreak
            } else {
                // Streak has expired
                currentStreak = 0
                userDefaults.set(0, forKey: Keys.currentStreak)
            }
        } else {
            currentStreak = 0
        }
    }
}
