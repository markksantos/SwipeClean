import Foundation

// MARK: - Photo Sort Order (for settings UI)
// Note: Core layer defines its own SortOrder in AlbumSource.swift for fetch queries.
// This enum adds .largestFirst and .random for the settings picker.

enum PhotoSortOrder: String, CaseIterable, Identifiable {
    case newestFirst = "newest_first"
    case oldestFirst = "oldest_first"
    case largestFirst = "largest_first"
    case random = "random"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .newestFirst: return "Newest First"
        case .oldestFirst: return "Oldest First"
        case .largestFirst: return "Largest First"
        case .random: return "Random"
        }
    }
}

// MARK: - Swipe Sensitivity

enum SwipeSensitivity: String, CaseIterable, Identifiable {
    case low
    case medium
    case high

    var id: String { rawValue }

    var threshold: CGFloat {
        switch self {
        case .low: return 160
        case .medium: return 120
        case .high: return 80
        }
    }

    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
}

// MARK: - Card Style

enum CardStyle: String, CaseIterable, Identifiable {
    case rounded
    case edgeToEdge = "edge_to_edge"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .rounded: return "Rounded"
        case .edgeToEdge: return "Edge-to-edge"
        }
    }
}

// MARK: - Settings Keys

enum SettingsKeys {
    static let sortOrder = "settings_sort_order"
    static let swipeSensitivity = "settings_swipe_sensitivity"
    static let hapticFeedback = "settings_haptic_feedback"
    static let autoPlayVideos = "settings_auto_play_videos"
    static let cardStyle = "settings_card_style"
}
