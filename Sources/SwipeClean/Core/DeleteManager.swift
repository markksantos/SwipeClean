import Photos
import Combine

/// Manages the deletion queue: collects swiped-left photos and batch-deletes at session end.
@MainActor
final class DeleteManager: ObservableObject {

    // MARK: - Public State

    @Published private(set) var trashQueue: [PhotoItem] = []

    var photosDeleted: Int { trashQueue.count }

    /// Total bytes queued for deletion.
    var queuedStorageBytes: Int64 {
        trashQueue.reduce(0) { $0 + $1.fileSize }
    }

    // MARK: - Private

    private let photoLibrary: PhotoLibraryPerforming

    // MARK: - Init

    init(photoLibrary: PhotoLibraryPerforming = PHPhotoLibrary.shared()) {
        self.photoLibrary = photoLibrary
    }

    // MARK: - Queue Operations

    /// Adds a photo to the trash queue without deleting it.
    ///
    /// Review counts deliberately live only on `SessionTracker`. This type used
    /// to keep its own `photosReviewed`/`photosKept` pair that no screen read and
    /// that only some call sites incremented, so the two disagreed by design.
    func queueForDeletion(_ item: PhotoItem) {
        trashQueue.append(item)
    }

    /// Removes the most recently queued item and returns it (for undo).
    /// Returns nil if the queue is empty.
    @discardableResult
    func undoLastDeletion() -> PhotoItem? {
        guard !trashQueue.isEmpty else { return nil }
        return trashQueue.removeLast()
    }

    /// Removes a specific photo from the trash queue by ID.
    /// Returns true if the photo was found and removed.
    @discardableResult
    func removeFromTrash(photoId: String) -> Bool {
        guard let index = trashQueue.firstIndex(where: { $0.id == photoId }) else { return false }
        trashQueue.remove(at: index)
        return true
    }

    /// Clears the trash queue without deleting anything.
    func clearQueue() {
        trashQueue.removeAll()
    }

    /// Resets the queue for a new session.
    func resetSession() {
        trashQueue.removeAll()
    }

    // MARK: - Batch Deletion

    /// Executes a single PHPhotoLibrary deletion request for all queued photos.
    /// Completion returns the number of photos deleted on success, or an error on failure.
    func executeQueuedDeletions(completion: @escaping (Result<Int, Error>) -> Void) {
        let itemsToDelete = trashQueue
        guard !itemsToDelete.isEmpty else {
            completion(.success(0))
            return
        }

        // Collect the real PHAssets. Items without an asset (e.g. test stubs)
        // contribute nothing to the change request but are still cleared from
        // the queue on success.
        let assets = itemsToDelete.compactMap { $0.asset }
        let submittedIDs = Set(itemsToDelete.map(\.id))

        photoLibrary.performChanges({
            // Only issue the delete request when there are real assets. An empty
            // request would throw inside PhotoKit's change block.
            guard !assets.isEmpty else { return }
            PHAssetChangeRequest.deleteAssets(assets as NSFastEnumeration)
        }, completionHandler: { [weak self] success, error in
            // PhotoKit calls back on a private queue; hop to the main actor
            // before touching any @Published state.
            Task { @MainActor [weak self] in
                self?.finishDeletion(
                    success: success,
                    error: error,
                    submittedIDs: submittedIDs,
                    completion: completion
                )
            }
        })
    }

    /// Main-actor continuation of `executeQueuedDeletions` once the library
    /// reports the result of the change request.
    ///
    /// Deleted assets always land in the system "Recently Deleted" album for 30
    /// days. PhotoKit exposes no API to bypass that, so the app must never claim
    /// otherwise — the deletion review screen says so explicitly.
    private func finishDeletion(
        success: Bool,
        error: (any Error)?,
        submittedIDs: Set<String>,
        completion: @escaping (Result<Int, Error>) -> Void
    ) {
        if success {
            // Clear only what was actually submitted. `removeAll()` also discarded
            // anything queued while the change request was in flight, so those
            // photos vanished from the queue without ever being deleted.
            let before = trashQueue.count
            trashQueue.removeAll { submittedIDs.contains($0.id) }
            completion(.success(before - trashQueue.count))
        } else {
            let deleteError = error ?? NSError(
                domain: "SwipeClean.DeleteManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Deletion was denied by the user."]
            )
            completion(.failure(deleteError))
        }
    }

    /// Async wrapper for executeQueuedDeletions.
    func executeDelete() async {
        await withCheckedContinuation { continuation in
            executeQueuedDeletions { _ in
                continuation.resume()
            }
        }
    }
}
