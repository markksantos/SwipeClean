import Foundation

/// A preset cleanup rule that can be toggled on/off by the user.
struct CleanupRule: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let iconName: String
    var isEnabled: Bool

    /// All available preset rules.
    static let allPresets: [CleanupRule] = [
        CleanupRule(
            id: "old_screenshots",
            name: "Old Screenshots",
            description: "Screenshots older than 6 months",
            iconName: "camera.viewfinder",
            isEnabled: false
        ),
        CleanupRule(
            id: "large_videos",
            name: "Large Videos",
            description: "Videos larger than 100 MB",
            iconName: "video.badge.exclamationmark",
            isEnabled: false
        ),
        CleanupRule(
            id: "old_no_faces",
            name: "Old Photos Without Faces",
            description: "Photos older than 1 year with no people",
            iconName: "person.crop.rectangle.badge.minus",
            isEnabled: false
        ),
        CleanupRule(
            id: "burst_photos",
            name: "Burst Photos",
            description: "Duplicate burst photo sequences",
            iconName: "square.stack.3d.down.right",
            isEnabled: false
        ),
        CleanupRule(
            id: "old_live_photos",
            name: "Old Live Photos",
            description: "Live Photos older than 6 months",
            iconName: "livephoto",
            isEnabled: false
        ),
    ]

    // MARK: - UserDefaults Persistence

    private static let enabledRulesKey = "cleanup_enabled_rules"

    /// Loads presets with persisted enabled state from UserDefaults.
    static func loadPresets(from defaults: UserDefaults = .standard) -> [CleanupRule] {
        let enabledIDs = Set(defaults.stringArray(forKey: enabledRulesKey) ?? [])
        return allPresets.map { rule in
            var copy = rule
            copy.isEnabled = enabledIDs.contains(rule.id)
            return copy
        }
    }

    /// Saves the set of enabled rule IDs to UserDefaults.
    static func saveEnabledRules(_ rules: [CleanupRule], to defaults: UserDefaults = .standard) {
        let enabledIDs = rules.filter(\.isEnabled).map(\.id)
        defaults.set(enabledIDs, forKey: enabledRulesKey)
    }
}
