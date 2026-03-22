import Foundation

// MARK: - Swipe Action

enum SwipeAction: Equatable {
    case kept
    case deleted
}

// MARK: - Swipe History Entry

struct SwipeHistoryEntry: Equatable {
    let action: SwipeAction
    let photoId: String
}

// MARK: - Swipe History

/// Stack-based undo history for swipe actions.
struct SwipeHistory {
    private var entries: [SwipeHistoryEntry] = []

    var canUndo: Bool {
        !entries.isEmpty
    }

    mutating func push(action: SwipeAction, photoId: String) {
        entries.append(SwipeHistoryEntry(action: action, photoId: photoId))
    }

    mutating func undo() -> SwipeHistoryEntry? {
        entries.popLast()
    }

    mutating func clear() {
        entries.removeAll()
    }
}
