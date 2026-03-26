import Foundation

/// A gamification milestone the user can earn.
struct Milestone: Identifiable {
    let id: String
    let title: String
    let description: String
    let icon: String          // SF Symbol name
    let category: Category
    let threshold: Int64

    enum Category: String, CaseIterable {
        case photosReviewed = "Photos Reviewed"
        case storageFreed = "Storage Freed"
        case streakDays = "Streak Days"
    }
}

/// Tracks which milestones have been achieved and checks for newly earned ones.
final class MilestoneTracker: ObservableObject {

    // MARK: - Keys

    private static let achievedKey = "sc_milestones_achieved"

    // MARK: - All Milestones

    static let allMilestones: [Milestone] = [
        // Photos Reviewed
        Milestone(id: "photos_100", title: "Getting Started", description: "Review 100 photos", icon: "eye.fill", category: .photosReviewed, threshold: 100),
        Milestone(id: "photos_500", title: "Photo Detective", description: "Review 500 photos", icon: "magnifyingglass", category: .photosReviewed, threshold: 500),
        Milestone(id: "photos_1000", title: "Curator", description: "Review 1,000 photos", icon: "star.fill", category: .photosReviewed, threshold: 1_000),
        Milestone(id: "photos_5000", title: "Master Curator", description: "Review 5,000 photos", icon: "crown.fill", category: .photosReviewed, threshold: 5_000),

        // Storage Freed
        Milestone(id: "storage_100mb", title: "Space Saver", description: "Free 100 MB of storage", icon: "externaldrive.fill", category: .storageFreed, threshold: 104_857_600),
        Milestone(id: "storage_500mb", title: "Storage Hero", description: "Free 500 MB of storage", icon: "bolt.fill", category: .storageFreed, threshold: 524_288_000),
        Milestone(id: "storage_1gb", title: "Giga Cleaner", description: "Free 1 GB of storage", icon: "flame.fill", category: .storageFreed, threshold: 1_073_741_824),
        Milestone(id: "storage_5gb", title: "Storage Legend", description: "Free 5 GB of storage", icon: "trophy.fill", category: .storageFreed, threshold: 5_368_709_120),

        // Streak Days
        Milestone(id: "streak_3", title: "On a Roll", description: "3 day streak", icon: "flame", category: .streakDays, threshold: 3),
        Milestone(id: "streak_7", title: "Week Warrior", description: "7 day streak", icon: "flame.fill", category: .streakDays, threshold: 7),
        Milestone(id: "streak_14", title: "Two Week Titan", description: "14 day streak", icon: "bolt.heart.fill", category: .streakDays, threshold: 14),
        Milestone(id: "streak_30", title: "Monthly Master", description: "30 day streak", icon: "medal.fill", category: .streakDays, threshold: 30),
    ]

    // MARK: - State

    @Published private(set) var achievedIDs: Set<String> = []
    @Published private(set) var newlyEarned: [Milestone] = []

    private let userDefaults: UserDefaultsStoring

    // MARK: - Init

    init(userDefaults: UserDefaultsStoring = UserDefaults.standard) {
        self.userDefaults = userDefaults
        loadAchieved()
    }

    // MARK: - Queries

    func isAchieved(_ milestone: Milestone) -> Bool {
        achievedIDs.contains(milestone.id)
    }

    /// Returns the most recently earned milestone, or nil.
    var lastEarned: Milestone? {
        // Return the last achieved milestone in definition order
        Self.allMilestones.last { achievedIDs.contains($0.id) }
    }

    /// Returns the next unearned milestone for a given category, or nil if all earned.
    func nextMilestone(for category: Milestone.Category) -> Milestone? {
        Self.allMilestones
            .filter { $0.category == category }
            .first { !achievedIDs.contains($0.id) }
    }

    // MARK: - Progress

    /// Returns fractional progress (0...1) toward the next milestone in a category.
    func progress(for category: Milestone.Category, currentValue: Int64) -> Double {
        guard let next = nextMilestone(for: category) else { return 1.0 }

        // Find previous threshold (or 0)
        let milestonesInCategory = Self.allMilestones.filter { $0.category == category }
        let previousThreshold: Int64
        if let idx = milestonesInCategory.firstIndex(where: { $0.id == next.id }), idx > 0 {
            previousThreshold = milestonesInCategory[idx - 1].threshold
        } else {
            previousThreshold = 0
        }

        let range = next.threshold - previousThreshold
        guard range > 0 else { return 0 }

        let progress = Double(currentValue - previousThreshold) / Double(range)
        return min(max(progress, 0), 1.0)
    }

    // MARK: - Check & Award

    /// Checks current stats and awards any newly earned milestones.
    /// Returns the list of milestones earned in this call.
    @discardableResult
    func checkAndAward(photosReviewed: Int, storageFreed: Int64, currentStreak: Int) -> [Milestone] {
        newlyEarned = []

        for milestone in Self.allMilestones {
            guard !achievedIDs.contains(milestone.id) else { continue }

            let earned: Bool
            switch milestone.category {
            case .photosReviewed:
                earned = Int64(photosReviewed) >= milestone.threshold
            case .storageFreed:
                earned = storageFreed >= milestone.threshold
            case .streakDays:
                earned = Int64(currentStreak) >= milestone.threshold
            }

            if earned {
                achievedIDs.insert(milestone.id)
                newlyEarned.append(milestone)
            }
        }

        if !newlyEarned.isEmpty {
            saveAchieved()
        }

        return newlyEarned
    }

    /// Clears newly earned list (after showing celebration).
    func clearNewlyEarned() {
        newlyEarned = []
    }

    /// Resets all milestone progress.
    func resetAll() {
        achievedIDs = []
        newlyEarned = []
        userDefaults.set(nil, forKey: Self.achievedKey)
    }

    // MARK: - Persistence

    private func loadAchieved() {
        if let saved = userDefaults.object(forKey: Self.achievedKey) as? [String] {
            achievedIDs = Set(saved)
        }
    }

    private func saveAchieved() {
        userDefaults.set(Array(achievedIDs) as Any, forKey: Self.achievedKey)
    }
}
