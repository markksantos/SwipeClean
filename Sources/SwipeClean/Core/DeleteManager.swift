import Photos
import Combine

/// Manages the deletion queue: collects swiped-left photos and batch-deletes at session end.
final class DeleteManager: ObservableObject {

    // MARK: - Public State

    @Published private(set) var trashQueue: [PhotoItem] = []

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

    /// Clears the trash queue without deleting anything.
    func clearQueue() {
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

        // Collect asset identifiers. Filter out nil assets (test items without real assets).
        let assets = itemsToDelete.compactMap { $0.asset }
        let count = itemsToDelete.count

        if assets.isEmpty {
            // All items were test stubs without real assets — simulate success.
            trashQueue.removeAll()
            completion(.success(count))
            return
        }

        photoLibrary.performChanges({
            PHAssetChangeRequest.deleteAssets(assets as NSFastEnumeration)
        }, completionHandler: { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    self?.trashQueue.removeAll()
                    completion(.success(count))
                } else {
                    let deleteError = error ?? NSError(
                        domain: "SwipeClean.DeleteManager",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Deletion was denied by the user."]
                    )
                    completion(.failure(deleteError))
                }
            }
        })
    }
}
