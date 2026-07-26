import Foundation

/// The single place a swipe decision is applied or taken back.
///
/// Recording a decision touches four objects — the history stack, the deletion
/// queue, the session counters, and the deck cursor — and both the gesture path
/// (`CardStack`) and the button path (`SwipeView`) need all four. They each used
/// to inline their own copy, which is how the button path ended up never
/// recording keeps on the deletion queue and how neither path ever rolled back
/// `SessionTracker` on undo.
@MainActor
struct SwipeCoordinator {
    let photoLoader: PhotoLoader
    let deleteManager: DeleteManager
    let sessionTracker: SessionTracker
    let swipeHistory: SwipeHistory

    /// Applies a keep/delete decision to the current photo and advances the deck.
    func record(_ action: SwipeAction, photo: PhotoItem) {
        swipeHistory.push(action: action, photoId: photo.id, photo: photo)
        sessionTracker.recordReview(kept: action == .kept, fileSize: photo.fileSize)

        if action == .deleted {
            deleteManager.queueForDeletion(photo)
        }

        photoLoader.advance()
    }

    /// Takes back the most recent decision, restoring the deck, the queue, and the
    /// session counters together.
    func undo() {
        guard let entry = swipeHistory.undo() else { return }

        photoLoader.goBack()

        if entry.action == .deleted {
            // Target the specific photo rather than the tail of the queue: the
            // user may have rescued something from the review grid since, in
            // which case the tail is a different photo entirely.
            deleteManager.removeFromTrash(photoId: entry.photoId)
        }

        sessionTracker.undoReview(kept: entry.action == .kept, fileSize: entry.photo.fileSize)
    }

    /// Flips an earlier decision from the history panel, without moving the deck.
    func toggle(entry: SwipeHistoryEntry) {
        let wasDeleted = entry.action == .deleted
        swipeHistory.toggleAction(for: entry.id)

        if wasDeleted {
            deleteManager.removeFromTrash(photoId: entry.photoId)
        } else {
            deleteManager.queueForDeletion(entry.photo)
        }

        // The counters have to move with the queue. Flipping a decision here used
        // to change only the queue, so the session summary and the lifetime
        // totals disagreed with what was about to be deleted.
        sessionTracker.undoReview(kept: !wasDeleted, fileSize: entry.photo.fileSize)
        sessionTracker.recordReview(kept: wasDeleted, fileSize: entry.photo.fileSize)
    }

    var canUndo: Bool { swipeHistory.canUndo }
}
