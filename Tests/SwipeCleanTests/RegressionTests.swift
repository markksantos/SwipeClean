import XCTest
import Photos
@testable import SwipeClean

/// Tests pinning behaviour that was previously wrong.
///
/// Each case here corresponds to a shipped defect: stats that drifted upward on
/// undo, a rescue button that freed the wrong photo, a delete button that
/// reported success after the user declined, and decoded images that were never
/// released. They are grouped so it is obvious what breaks if one regresses.

private func stub(
    id: String,
    fileSize: Int64 = 1_000_000,
    mediaType: PhotoMediaType = .image
) -> PhotoItem {
    PhotoItem(
        id: id,
        asset: nil,
        creationDate: nil,
        mediaType: mediaType,
        fileSize: fileSize,
        duration: nil,
        isFavorited: false
    )
}

// MARK: - Undo keeps the queue and the counters in agreement

@MainActor
final class SwipeCoordinatorTests: XCTestCase {

    private func makeCoordinator(
        itemCount: Int = 10
    ) -> (SwipeCoordinator, PhotoLoader, DeleteManager, SessionTracker, MockUserDefaults) {
        let loader = PhotoLoader(imageLoader: MockImageLoader(), assetFetcher: MockAssetFetcher())
        loader.loadItems((0..<itemCount).map { stub(id: "photo-\($0)") })

        let deleteManager = DeleteManager(photoLibrary: MockPhotoLibrary())
        let defaults = MockUserDefaults()
        let tracker = SessionTracker(userDefaults: defaults)
        tracker.startSession()

        let coordinator = SwipeCoordinator(
            photoLoader: loader,
            deleteManager: deleteManager,
            sessionTracker: tracker,
            swipeHistory: SwipeHistory()
        )
        return (coordinator, loader, deleteManager, tracker, defaults)
    }

    func test_recording_a_keep_counts_it_as_reviewed() {
        let (coordinator, loader, deleteManager, tracker, _) = makeCoordinator()
        let photo = loader.currentPhoto!

        coordinator.record(.kept, photo: photo)

        XCTAssertEqual(tracker.sessionStats.photosReviewed, 1)
        XCTAssertEqual(tracker.sessionStats.photosKept, 1)
        XCTAssertEqual(tracker.sessionStats.photosDeleted, 0)
        XCTAssertTrue(deleteManager.trashQueue.isEmpty)
        XCTAssertEqual(loader.currentIndex, 1)
    }

    func test_recording_a_delete_queues_and_counts_it() {
        let (coordinator, loader, deleteManager, tracker, _) = makeCoordinator()
        let photo = loader.currentPhoto!

        coordinator.record(.deleted, photo: photo)

        XCTAssertEqual(deleteManager.trashQueue.map(\.id), [photo.id])
        XCTAssertEqual(tracker.sessionStats.photosDeleted, 1)
        XCTAssertEqual(tracker.sessionStats.storageFreed, 1_000_000)
    }

    /// The regression: undo rewound the deck and the queue but never the session
    /// counters, so "photos cleaned" and "storage freed" only ever grew — and
    /// `endSession()` then wrote those inflated numbers into the lifetime totals.
    func test_undoing_a_delete_rolls_back_the_session_counters() {
        let (coordinator, loader, deleteManager, tracker, _) = makeCoordinator()

        coordinator.record(.deleted, photo: loader.currentPhoto!)
        coordinator.undo()

        XCTAssertTrue(deleteManager.trashQueue.isEmpty)
        XCTAssertEqual(tracker.sessionStats.photosReviewed, 0)
        XCTAssertEqual(tracker.sessionStats.photosDeleted, 0)
        XCTAssertEqual(tracker.sessionStats.storageFreed, 0)
        XCTAssertEqual(loader.currentIndex, 0)
    }

    func test_undoing_a_keep_rolls_back_the_session_counters() {
        let (coordinator, loader, _, tracker, _) = makeCoordinator()

        coordinator.record(.kept, photo: loader.currentPhoto!)
        coordinator.undo()

        XCTAssertEqual(tracker.sessionStats.photosReviewed, 0)
        XCTAssertEqual(tracker.sessionStats.photosKept, 0)
    }

    func test_undo_does_not_persist_inflated_lifetime_totals() {
        let (coordinator, loader, _, tracker, defaults) = makeCoordinator()

        coordinator.record(.deleted, photo: loader.currentPhoto!)
        coordinator.record(.deleted, photo: loader.currentPhoto!)
        coordinator.undo()
        tracker.endSession()

        XCTAssertEqual(defaults.integer(forKey: "sc_lifetime_deleted"), 1)
        XCTAssertEqual(defaults.integer(forKey: "sc_lifetime_reviewed"), 1)
        XCTAssertEqual(defaults.integer(forKey: "sc_lifetime_storage_freed"), 1_000_000)
    }

    /// Undo has to release the photo the history entry names. Popping the tail of
    /// the queue instead freed an unrelated photo whenever the user had already
    /// rescued something from the review grid.
    func test_undo_releases_the_photo_named_by_the_history_entry() {
        let (coordinator, loader, deleteManager, _, _) = makeCoordinator()

        let first = loader.currentPhoto!
        coordinator.record(.deleted, photo: first)
        let second = loader.currentPhoto!
        coordinator.record(.deleted, photo: second)

        // Rescue the *first* photo out of order, as the review grid allows.
        deleteManager.removeFromTrash(photoId: first.id)
        XCTAssertEqual(deleteManager.trashQueue.map(\.id), [second.id])

        coordinator.undo()

        XCTAssertTrue(
            deleteManager.trashQueue.isEmpty,
            "Undo must release the second photo, which the history entry names"
        )
    }

    func test_toggling_a_decision_moves_the_counters_with_the_queue() {
        let (coordinator, loader, deleteManager, tracker, _) = makeCoordinator()

        let photo = loader.currentPhoto!
        coordinator.record(.kept, photo: photo)
        let entry = coordinator.swipeHistory.entries[0]

        coordinator.toggle(entry: entry)

        XCTAssertEqual(deleteManager.trashQueue.map(\.id), [photo.id])
        XCTAssertEqual(tracker.sessionStats.photosKept, 0)
        XCTAssertEqual(tracker.sessionStats.photosDeleted, 1)
        XCTAssertEqual(tracker.sessionStats.storageFreed, 1_000_000)
        XCTAssertEqual(
            tracker.sessionStats.photosReviewed, 1,
            "Flipping a decision must not double-count the review"
        )

        coordinator.toggle(entry: entry)

        XCTAssertTrue(deleteManager.trashQueue.isEmpty)
        XCTAssertEqual(tracker.sessionStats.photosKept, 1)
        XCTAssertEqual(tracker.sessionStats.photosDeleted, 0)
        XCTAssertEqual(tracker.sessionStats.storageFreed, 0)
    }

    func test_undo_on_empty_history_is_a_no_op() {
        let (coordinator, loader, _, tracker, _) = makeCoordinator()

        coordinator.undo()

        XCTAssertEqual(loader.currentIndex, 0)
        XCTAssertEqual(tracker.sessionStats.photosReviewed, 0)
    }
}

// MARK: - Session counters never go negative

final class SessionTrackerUndoTests: XCTestCase {

    func test_undo_cannot_drive_counters_below_zero() {
        let tracker = SessionTracker(userDefaults: MockUserDefaults())
        tracker.startSession()

        tracker.undoReview(kept: false, fileSize: 5_000)
        tracker.undoReview(kept: true, fileSize: 5_000)

        XCTAssertEqual(tracker.sessionStats.photosReviewed, 0)
        XCTAssertEqual(tracker.sessionStats.photosDeleted, 0)
        XCTAssertEqual(tracker.sessionStats.storageFreed, 0)
    }

    func test_undo_of_a_keep_does_not_touch_deleted_counters() {
        let tracker = SessionTracker(userDefaults: MockUserDefaults())
        tracker.startSession()

        tracker.recordReview(kept: false, fileSize: 400)
        tracker.recordReview(kept: true, fileSize: 900)
        tracker.undoReview(kept: true, fileSize: 900)

        XCTAssertEqual(tracker.sessionStats.photosDeleted, 1)
        XCTAssertEqual(tracker.sessionStats.storageFreed, 400)
        XCTAssertEqual(tracker.sessionStats.photosKept, 0)
        XCTAssertEqual(tracker.sessionStats.photosReviewed, 1)
    }

    /// Guards the mismatched-kind case: rolling back a keep when only deletes were
    /// recorded must not silently decrement the delete counters.
    func test_undo_of_a_keep_with_no_keeps_recorded_is_a_no_op() {
        let tracker = SessionTracker(userDefaults: MockUserDefaults())
        tracker.startSession()

        tracker.recordReview(kept: false, fileSize: 400)
        tracker.undoReview(kept: true, fileSize: 400)

        XCTAssertEqual(tracker.sessionStats.photosReviewed, 1)
        XCTAssertEqual(tracker.sessionStats.photosDeleted, 1)
        XCTAssertEqual(tracker.sessionStats.storageFreed, 400)
    }
}

// MARK: - Deletion clears only what it submitted

@MainActor
final class DeleteManagerSubmissionTests: XCTestCase {

    func test_photos_queued_during_an_in_flight_delete_survive() {
        let library = DeferredPhotoLibrary()
        let manager = DeleteManager(photoLibrary: library)

        manager.queueForDeletion(stub(id: "submitted"))

        var reported: Int?
        manager.executeQueuedDeletions { result in
            reported = try? result.get()
        }

        // Queued after the change request went out, so it was never submitted.
        manager.queueForDeletion(stub(id: "late"))
        library.finish(success: true)

        XCTAssertEqual(reported, 1, "Only the submitted photo was deleted")
        XCTAssertEqual(
            manager.trashQueue.map(\.id), ["late"],
            "Clearing the whole queue silently discarded photos that were never deleted"
        )
    }

    func test_a_declined_deletion_reports_failure_and_keeps_the_queue() async {
        let library = MockPhotoLibrary()
        library.shouldSucceed = false
        let manager = DeleteManager(photoLibrary: library)
        manager.queueForDeletion(stub(id: "a"))

        // `DeleteManager` finishes on the main actor, so the result arrives a hop
        // after `executeQueuedDeletions` returns rather than inline.
        let result: Result<Int, Error> = await withCheckedContinuation { continuation in
            manager.executeQueuedDeletions { continuation.resume(returning: $0) }
        }

        guard case .failure = result else {
            return XCTFail("Declining the system prompt must surface as a failure")
        }
        XCTAssertEqual(manager.trashQueue.count, 1, "Nothing was deleted, so nothing may leave the queue")
    }

    func test_removeFromTrash_targets_the_named_photo() {
        let manager = DeleteManager(photoLibrary: MockPhotoLibrary())
        manager.queueForDeletion(stub(id: "a"))
        manager.queueForDeletion(stub(id: "b"))
        manager.queueForDeletion(stub(id: "c"))

        XCTAssertTrue(manager.removeFromTrash(photoId: "a"))

        XCTAssertEqual(manager.trashQueue.map(\.id), ["b", "c"])
        XCTAssertFalse(manager.removeFromTrash(photoId: "zzz"))
    }
}

/// A library that hands back control before completing, so a test can queue more
/// work while a change request is still in flight.
final class DeferredPhotoLibrary: PhotoLibraryPerforming, @unchecked Sendable {
    private var completion: (@Sendable (Bool, (any Error)?) -> Void)?

    func performChanges(
        _ changeBlock: @escaping @Sendable () -> Void,
        completionHandler: (@Sendable (Bool, (any Error)?) -> Void)?
    ) {
        changeBlock()
        completion = completionHandler
    }

    func finish(success: Bool) {
        let handler = completion
        completion = nil
        handler?(success, nil)
        // `DeleteManager` hops to the main actor before touching its state, so let
        // that hop land before the test asserts.
        let expectation = XCTestExpectation(description: "main-actor hop")
        DispatchQueue.main.async { expectation.fulfill() }
        _ = XCTWaiter().wait(for: [expectation], timeout: 1)
    }
}

// MARK: - Decoded images are released as the deck moves on

final class PhotoLoaderMemoryTests: XCTestCase {

    private func pixel() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
    }

    /// The regression: nothing ever cleared `thumbnail`/`fullImage`, so a session
    /// on a large library accumulated a screen-sized image per reviewed photo
    /// until the app was jetsammed.
    func test_advancing_releases_images_left_behind_by_the_window() {
        let loader = PhotoLoader(imageLoader: MockImageLoader(), assetFetcher: MockAssetFetcher())
        let items = (0..<60).map { stub(id: "photo-\($0)") }
        loader.loadItems(items)

        for item in items.prefix(3) {
            loader.store(pixel(), on: item, keyPath: \.fullImage)
        }
        XCTAssertEqual(loader.decodedImageCount, 3)

        // Half-window is 10, so 25 advances leaves the first three well outside it.
        for _ in 0..<25 { loader.advance() }

        XCTAssertEqual(loader.decodedImageCount, 0)
        for item in items.prefix(3) {
            XCTAssertNil(item.fullImage)
            XCTAssertNil(item.thumbnail)
        }
    }

    func test_images_inside_the_window_are_kept() {
        let loader = PhotoLoader(imageLoader: MockImageLoader(), assetFetcher: MockAssetFetcher())
        let items = (0..<60).map { stub(id: "photo-\($0)") }
        loader.loadItems(items)

        loader.advance()
        loader.store(pixel(), on: items[1], keyPath: \.fullImage)
        loader.advance()

        XCTAssertNotNil(items[1].fullImage, "The photo one step back is still on screen for undo")
        XCTAssertEqual(loader.decodedImageCount, 1)
    }

    func test_loading_a_new_album_releases_the_previous_one() {
        let loader = PhotoLoader(imageLoader: MockImageLoader(), assetFetcher: MockAssetFetcher())
        let first = (0..<5).map { stub(id: "first-\($0)") }
        loader.loadItems(first)
        loader.store(pixel(), on: first[0], keyPath: \.fullImage)

        loader.loadItems((0..<5).map { stub(id: "second-\($0)") })

        XCTAssertNil(first[0].fullImage)
        XCTAssertEqual(loader.decodedImageCount, 0)
    }

    /// PhotoKit measures `targetSize` in pixels, so requesting point dimensions
    /// produced a card image at a third of the resolution it was drawn at.
    func test_display_image_size_is_in_pixels() {
        let loader = PhotoLoader(imageLoader: MockImageLoader(), assetFetcher: MockAssetFetcher())

        XCTAssertGreaterThan(
            loader.displayImageSize.width, 700,
            "A point-sized request would be ~440 wide and land visibly soft"
        )
    }
}

// MARK: - Pro gating

@MainActor
final class ProGatingTests: XCTestCase {

    /// A throwaway suite so seeding the entitlement flag cannot touch the
    /// simulator's real defaults or leak between tests.
    private func defaults(unlocked: Bool) -> UserDefaults {
        let suite = "swipeclean.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.set(unlocked, forKey: "sc_pro_unlocked")
        return defaults
    }

    func test_every_pro_feature_is_locked_without_a_purchase() {
        let pro = ProManager(defaults: defaults(unlocked: false))

        XCTAssertFalse(pro.isPro)
        for feature in ProFeature.allCases {
            XCTAssertTrue(pro.isLocked(feature), "\(feature.title) must be gated")
        }
    }

    func test_a_cached_entitlement_unlocks_before_the_store_answers() {
        // Without this the gated rows flash locked on every cold launch.
        let pro = ProManager(defaults: defaults(unlocked: true))

        XCTAssertTrue(pro.isPro)
        for feature in ProFeature.allCases {
            XCTAssertFalse(pro.isLocked(feature))
        }
    }

    /// Swiping is the product. Metering it would earn one-star reviews for the
    /// exact thing the listing promises, so no plain album may ever be gated.
    func test_plain_albums_are_never_gated() {
        let pro = ProManager(defaults: defaults(unlocked: false))
        let free: [AlbumSource] = [
            .allPhotos, .recents, .screenshots, .videos, .selfies,
            .livePhotos, .favorites, .onThisDay, .random, .duplicates,
            .month(2026, 3),
        ]

        for source in free {
            XCTAssertNil(pro.feature(for: source), "\(source.displayName) must stay free")
            XCTAssertFalse(pro.isLocked(source))
        }
    }

    func test_automation_sources_map_to_their_features() {
        let pro = ProManager(defaults: defaults(unlocked: false))

        XCTAssertEqual(pro.feature(for: .smartCleanup), .smartCleanup)
        XCTAssertEqual(pro.feature(for: .similarPhotos), .similarPhotos)
        XCTAssertEqual(pro.feature(for: .autoClean), .autoClean)
    }

    func test_every_feature_has_a_title_icon_and_pitch() {
        // The paywall renders all four unconditionally; an empty string there is a
        // visible blank row rather than a crash, so assert on content.
        for feature in ProFeature.allCases {
            XCTAssertFalse(feature.title.isEmpty)
            XCTAssertFalse(feature.icon.isEmpty)
            XCTAssertGreaterThan(feature.pitch.count, 30, "\(feature.title) needs a real pitch")
        }
    }
}
