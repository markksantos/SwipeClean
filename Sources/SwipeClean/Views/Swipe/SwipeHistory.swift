import Foundation

// MARK: - Swipe Action

enum SwipeAction: Equatable {
    case kept
    case deleted
}

// MARK: - Swipe History Entry

/// A single swipe decision, identified by UUID for random-access undo.
final class SwipeHistoryEntry: Identifiable, ObservableObject {
    let id = UUID()
    let photoId: String
    let photo: PhotoItem
    let timestamp: Date
    @Published var action: SwipeAction

    init(action: SwipeAction, photoId: String, photo: PhotoItem, timestamp: Date = Date()) {
        self.action = action
        self.photoId = photoId
        self.photo = photo
        self.timestamp = timestamp
    }
}

extension SwipeHistoryEntry: Equatable {
    static func == (lhs: SwipeHistoryEntry, rhs: SwipeHistoryEntry) -> Bool {
        lhs.id == rhs.id && lhs.action == rhs.action
    }
}

// MARK: - Swipe History

/// Observable undo history for swipe actions. Supports both stack-based and random-access undo.
final class SwipeHistory: ObservableObject {
    @Published private(set) var entries: [SwipeHistoryEntry] = []

    var canUndo: Bool {
        !entries.isEmpty
    }

    func push(action: SwipeAction, photoId: String, photo: PhotoItem) {
        let entry = SwipeHistoryEntry(action: action, photoId: photoId, photo: photo)
        entries.append(entry)
    }

    /// Stack-based undo: removes and returns the last entry.
    @discardableResult
    func undo() -> SwipeHistoryEntry? {
        entries.popLast()
    }

    /// Random-access undo: toggles the action on a specific entry (kept <-> deleted).
    /// Returns the entry after toggling so the caller can react.
    @discardableResult
    func toggleAction(for entryId: UUID) -> SwipeHistoryEntry? {
        guard let index = entries.firstIndex(where: { $0.id == entryId }) else { return nil }
        let entry = entries[index]
        entry.action = (entry.action == .kept) ? .deleted : .kept
        // Trigger @Published update
        objectWillChange.send()
        return entry
    }

    func clear() {
        entries.removeAll()
    }

    /// Entries in reverse chronological order (most recent first).
    var reversedEntries: [SwipeHistoryEntry] {
        entries.reversed()
    }
}
