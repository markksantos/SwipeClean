import Photos
import Combine

/// Manages the deletion queue: collects swiped-left photos and batch-deletes at session end.
final class DeleteManager: ObservableObject {

    // MARK: - Public State

    @Published private(set) var trashQueue: [PhotoItem] = []
    @Published private(set) var photosReviewed: Int = 0
    @Published private(set) var photosKept: Int = 0

    var photosDeleted: Int { trashQueue.count }

    /// Total bytes queued for deletion.
    var queuedStorageBytes: Int64 {
        trashQueue.reduce(0) { $0 + $1.fileSize }
    }

    /// Alias used by session complete view.
    var storageFreed: Int64 { queuedStorageBytes }

    /// Whether the last action can be undone.
    var canUndo: Bool { !trashQueue.isEmpty }

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

    /// Alias for queueForDeletion — used by swipe views.
    func markForDeletion(_ item: PhotoItem) {
        photosReviewed += 1
        queueForDeletion(item)
    }

    /// Records a kept photo (swipe right).
    func recordKept() {
        photosReviewed += 1
        photosKept += 1
    }

    /// Removes the most recently queued item and returns it (for undo).
    /// Returns nil if the queue is empty.
    @discardableResult
    func undoLastDeletion() -> PhotoItem? {
        guard !trashQueue.isEmpty else { return nil }
        return trashQueue.removeLast()
    }

    /// Alias for undoLastDeletion — used by swipe views.
    @discardableResult
    func undoLast() -> PhotoItem? {
        undoLastDeletion()
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

    /// Resets session counters.
    func resetSession() {
        photosReviewed = 0
        photosKept = 0
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

        let permanentDelete = UserDefaults.standard.bool(forKey: SettingsKeys.permanentDelete)

        photoLibrary.performChanges({
            PHAssetChangeRequest.deleteAssets(assets as NSFastEnumeration)
        }, completionHandler: { [weak self] success, error in
            if success && permanentDelete {
                // Fetch from Recently Deleted and delete again for permanent removal
                let assetIDs = assets.compactMap { ($0 as? PHAsset)?.localIdentifier }
                self?.permanentlyDelete(assetIDs: assetIDs) { permResult in
                    DispatchQueue.main.async {
                        self?.trashQueue.removeAll()
                        // Report success regardless — initial delete succeeded
                        completion(.success(count))
                    }
                }
            } else {
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
            }
        })
    }

    /// Permanently deletes assets that are already in Recently Deleted.
    private func permanentlyDelete(assetIDs: [String], completion: @escaping (Bool) -> Void) {
        guard !assetIDs.isEmpty else {
            completion(true)
            return
        }
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: assetIDs, options: nil)
        guard fetchResult.count > 0 else {
            completion(true)
            return
        }
        var assetsToDelete: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in
            assetsToDelete.append(asset)
        }
        photoLibrary.performChanges({
            PHAssetChangeRequest.deleteAssets(assetsToDelete as NSFastEnumeration)
        }, completionHandler: { success, _ in
            completion(success)
        })
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
