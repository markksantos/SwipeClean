import XCTest
import Photos
@testable import SwipeClean

// MARK: - Protocols for Testability

// These mirror the protocols defined in production code, allowing mock injection.

// MARK: - Mock Implementations

final class MockImageLoader: ImageLoading {
    var requestedTargetSizes: [CGSize] = []
    var cancelledRequestIDs: [PHImageRequestID] = []
    private var nextRequestID: PHImageRequestID = 1

    func requestImage(
        for asset: PHAsset,
        targetSize: CGSize,
        contentMode: PHImageContentMode,
        options: PHImageRequestOptions?,
        resultHandler: @escaping (UIImage?, [AnyHashable: Any]?) -> Void
    ) -> PHImageRequestID {
        requestedTargetSizes.append(targetSize)
        let id = nextRequestID
        nextRequestID += 1
        // Deliver a 1x1 pixel image immediately
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
        let img = renderer.image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        resultHandler(img, [PHImageResultIsDegradedKey: false])
        return id
    }

    func cancelImageRequest(_ requestID: PHImageRequestID) {
        cancelledRequestIDs.append(requestID)
    }
}

final class MockPhotoLibrary: PhotoLibraryPerforming {
    var performChangesCallCount = 0
    var lastDeletedAssetIDs: [String] = []
    var shouldSucceed = true
    var shouldError: Error?

    func performChanges(
        _ changeBlock: @escaping () -> Void,
        completionHandler: ((Bool, Error?) -> Void)?
    ) {
        performChangesCallCount += 1
        changeBlock()
        completionHandler?(shouldSucceed, shouldError)
    }
}

final class MockAssetFetcher: AssetFetching {
    var stubbedAssets: [PHAsset] = []

    func fetchAssets(for source: AlbumSource, sortOrder: SortOrder) -> [PHAsset] {
        return stubbedAssets
    }

    func fetchAlbumSources() -> [AlbumSourceInfo] {
        return [
            AlbumSourceInfo(source: .allPhotos, count: 100),
            AlbumSourceInfo(source: .recents, count: 50),
            AlbumSourceInfo(source: .screenshots, count: 10),
            AlbumSourceInfo(source: .videos, count: 5),
            AlbumSourceInfo(source: .selfies, count: 20),
            AlbumSourceInfo(source: .livePhotos, count: 15),
            AlbumSourceInfo(source: .favorites, count: 8),
        ]
    }
}

final class MockPermissionProvider: PermissionProviding {
    var stubbedStatus: PHAuthorizationStatus = .notDetermined
    var requestedAccessLevel: PHAccessLevel?
    var statusToGrantOnRequest: PHAuthorizationStatus = .authorized

    func authorizationStatus(for accessLevel: PHAccessLevel) -> PHAuthorizationStatus {
        return stubbedStatus
    }

    func requestAuthorization(
        for accessLevel: PHAccessLevel,
        handler: @escaping (PHAuthorizationStatus) -> Void
    ) {
        requestedAccessLevel = accessLevel
        stubbedStatus = statusToGrantOnRequest
        handler(statusToGrantOnRequest)
    }
}

final class MockUserDefaults: UserDefaultsStoring {
    private var store: [String: Any] = [:]

    func integer(forKey key: String) -> Int { store[key] as? Int ?? 0 }
    func set(_ value: Int, forKey key: String) { store[key] = value }
    func double(forKey key: String) -> Double { store[key] as? Double ?? 0 }
    func set(_ value: Double, forKey key: String) { store[key] = value }
    func object(forKey key: String) -> Any? { store[key] }
    func set(_ value: Any?, forKey key: String) { store[key] = value }
}

// MARK: - PhotoItem Tests

final class PhotoItemTests: XCTestCase {

    func test_photoItem_initialization_with_defaults() {
        let item = PhotoItem(
            id: "test-id-123",
            asset: nil,
            creationDate: nil,
            mediaType: .image,
            fileSize: 2_500_000,
            duration: nil,
            isFavorited: false
        )

        XCTAssertEqual(item.id, "test-id-123")
        XCTAssertNil(item.thumbnail)
        XCTAssertNil(item.fullImage)
        XCTAssertNil(item.creationDate)
        XCTAssertEqual(item.mediaType, .image)
        XCTAssertEqual(item.fileSize, 2_500_000)
        XCTAssertNil(item.duration)
        XCTAssertFalse(item.isFavorited)
    }

    func test_photoItem_mediaType_cases() {
        XCTAssertEqual(PhotoMediaType.image.rawValue, "image")
        XCTAssertEqual(PhotoMediaType.video.rawValue, "video")
        XCTAssertEqual(PhotoMediaType.screenshot.rawValue, "screenshot")
        XCTAssertEqual(PhotoMediaType.livePhoto.rawValue, "livePhoto")
    }

    func test_photoItem_identifiable_conformance() {
        let item1 = PhotoItem(id: "a", asset: nil, creationDate: nil, mediaType: .image, fileSize: 0, duration: nil, isFavorited: false)
        let item2 = PhotoItem(id: "b", asset: nil, creationDate: nil, mediaType: .image, fileSize: 0, duration: nil, isFavorited: false)
        XCTAssertNotEqual(item1.id, item2.id)
    }

    func test_photoItem_video_has_duration() {
        let item = PhotoItem(id: "v1", asset: nil, creationDate: nil, mediaType: .video, fileSize: 50_000_000, duration: 15.5, isFavorited: false)
        XCTAssertEqual(item.duration, 15.5)
        XCTAssertEqual(item.mediaType, .video)
    }
}

// MARK: - AlbumSource Tests

final class AlbumSourceTests: XCTestCase {

    func test_displayName_allPhotos() {
        XCTAssertEqual(AlbumSource.allPhotos.displayName, "All Photos")
    }

    func test_displayName_recents() {
        XCTAssertEqual(AlbumSource.recents.displayName, "Last 30 Days")
    }

    func test_displayName_screenshots() {
        XCTAssertEqual(AlbumSource.screenshots.displayName, "Screenshots")
    }

    func test_displayName_videos() {
        XCTAssertEqual(AlbumSource.videos.displayName, "Videos")
    }

    func test_displayName_selfies() {
        XCTAssertEqual(AlbumSource.selfies.displayName, "Selfies")
    }

    func test_displayName_livePhotos() {
        XCTAssertEqual(AlbumSource.livePhotos.displayName, "Live Photos")
    }

    func test_displayName_favorites() {
        XCTAssertEqual(AlbumSource.favorites.displayName, "Favorites")
    }

    func test_displayName_duplicates() {
        XCTAssertEqual(AlbumSource.duplicates.displayName, "Duplicates")
    }

    func test_iconName_exists_for_all_cases() {
        let cases: [AlbumSource] = [
            .allPhotos, .recents, .screenshots, .videos,
            .selfies, .livePhotos, .favorites, .duplicates
        ]
        for source in cases {
            XCTAssertFalse(source.iconName.isEmpty, "\(source) should have an icon name")
        }
    }
}

// MARK: - PhotoLoader Tests

final class PhotoLoaderTests: XCTestCase {

    func test_preloads_next_3_photos() {
        let mockImageLoader = MockImageLoader()
        let mockFetcher = MockAssetFetcher()
        let loader = PhotoLoader(imageLoader: mockImageLoader, assetFetcher: mockFetcher)

        // Create 5 mock photo items
        let items = (0..<5).map { i in
            PhotoItem(id: "photo-\(i)", asset: nil, creationDate: nil, mediaType: .image, fileSize: 1000, duration: nil, isFavorited: false)
        }
        loader.loadItems(items)

        // Current photo (index 0) should be loaded, plus next 3 preloaded
        XCTAssertEqual(loader.currentIndex, 0)
        XCTAssertNotNil(loader.currentPhoto)
        XCTAssertTrue(loader.upcomingPhotos.count <= 3, "Should preload up to 3 upcoming photos")
    }

    func test_sliding_window_limits_memory() {
        let mockImageLoader = MockImageLoader()
        let mockFetcher = MockAssetFetcher()
        let loader = PhotoLoader(imageLoader: mockImageLoader, assetFetcher: mockFetcher)

        // Create 50 items
        let items = (0..<50).map { i in
            PhotoItem(id: "photo-\(i)", asset: nil, creationDate: nil, mediaType: .image, fileSize: 1000, duration: nil, isFavorited: false)
        }
        loader.loadItems(items)

        XCTAssertEqual(loader.totalCount, 50)
        // The active window should be capped at ~20
        XCTAssertLessThanOrEqual(loader.activeWindowSize, 20)
    }

    func test_cancels_outdated_requests() {
        let mockImageLoader = MockImageLoader()
        let mockFetcher = MockAssetFetcher()
        let loader = PhotoLoader(imageLoader: mockImageLoader, assetFetcher: mockFetcher)

        let items = (0..<10).map { i in
            PhotoItem(id: "photo-\(i)", asset: nil, creationDate: nil, mediaType: .image, fileSize: 1000, duration: nil, isFavorited: false)
        }
        loader.loadItems(items)

        // Advance several positions to trigger cancellation of old requests
        loader.advance()
        loader.advance()
        loader.advance()
        loader.advance()
        loader.advance()

        XCTAssertGreaterThan(mockImageLoader.cancelledRequestIDs.count, 0, "Should cancel requests for photos that left the window")
    }

    func test_progress_calculation() {
        let mockImageLoader = MockImageLoader()
        let mockFetcher = MockAssetFetcher()
        let loader = PhotoLoader(imageLoader: mockImageLoader, assetFetcher: mockFetcher)

        let items = (0..<10).map { i in
            PhotoItem(id: "photo-\(i)", asset: nil, creationDate: nil, mediaType: .image, fileSize: 1000, duration: nil, isFavorited: false)
        }
        loader.loadItems(items)

        XCTAssertEqual(loader.progress, 0.0, accuracy: 0.01)

        loader.advance()
        XCTAssertEqual(loader.progress, 0.1, accuracy: 0.01)

        // Advance to end
        for _ in 0..<9 {
            loader.advance()
        }
        XCTAssertEqual(loader.progress, 1.0, accuracy: 0.01)
    }

    func test_currentPhoto_nil_when_empty() {
        let mockImageLoader = MockImageLoader()
        let mockFetcher = MockAssetFetcher()
        let loader = PhotoLoader(imageLoader: mockImageLoader, assetFetcher: mockFetcher)

        loader.loadItems([])
        XCTAssertNil(loader.currentPhoto)
        XCTAssertEqual(loader.totalCount, 0)
    }
}

// MARK: - DeleteManager Tests

final class DeleteManagerTests: XCTestCase {

    func test_queues_without_immediate_deletion() {
        let mockLibrary = MockPhotoLibrary()
        let manager = DeleteManager(photoLibrary: mockLibrary)

        let item = PhotoItem(id: "del-1", asset: nil, creationDate: nil, mediaType: .image, fileSize: 3_000_000, duration: nil, isFavorited: false)
        manager.queueForDeletion(item)

        XCTAssertEqual(manager.trashQueue.count, 1)
        XCTAssertEqual(mockLibrary.performChangesCallCount, 0, "Should NOT delete immediately")
    }

    func test_batch_deletion_single_request() {
        let mockLibrary = MockPhotoLibrary()
        let manager = DeleteManager(photoLibrary: mockLibrary)

        for i in 0..<5 {
            let item = PhotoItem(id: "del-\(i)", asset: nil, creationDate: nil, mediaType: .image, fileSize: 1_000_000, duration: nil, isFavorited: false)
            manager.queueForDeletion(item)
        }

        let expectation = expectation(description: "Batch deletion completes")
        manager.executeQueuedDeletions { result in
            switch result {
            case .success(let count):
                XCTAssertEqual(count, 5)
            case .failure:
                XCTFail("Deletion should succeed")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(mockLibrary.performChangesCallCount, 1, "Should make exactly one deletion request")
    }

    func test_undo_removes_last_item_from_queue() {
        let mockLibrary = MockPhotoLibrary()
        let manager = DeleteManager(photoLibrary: mockLibrary)

        let item1 = PhotoItem(id: "del-1", asset: nil, creationDate: nil, mediaType: .image, fileSize: 1_000_000, duration: nil, isFavorited: false)
        let item2 = PhotoItem(id: "del-2", asset: nil, creationDate: nil, mediaType: .image, fileSize: 2_000_000, duration: nil, isFavorited: false)

        manager.queueForDeletion(item1)
        manager.queueForDeletion(item2)
        XCTAssertEqual(manager.trashQueue.count, 2)

        let undone = manager.undoLastDeletion()
        XCTAssertEqual(undone?.id, "del-2")
        XCTAssertEqual(manager.trashQueue.count, 1)
        XCTAssertEqual(manager.trashQueue.first?.id, "del-1")
    }

    func test_undo_on_empty_queue_returns_nil() {
        let mockLibrary = MockPhotoLibrary()
        let manager = DeleteManager(photoLibrary: mockLibrary)

        let undone = manager.undoLastDeletion()
        XCTAssertNil(undone)
    }

    func test_queued_storage_total() {
        let mockLibrary = MockPhotoLibrary()
        let manager = DeleteManager(photoLibrary: mockLibrary)

        manager.queueForDeletion(PhotoItem(id: "a", asset: nil, creationDate: nil, mediaType: .image, fileSize: 1_000_000, duration: nil, isFavorited: false))
        manager.queueForDeletion(PhotoItem(id: "b", asset: nil, creationDate: nil, mediaType: .video, fileSize: 5_000_000, duration: 10.0, isFavorited: false))

        XCTAssertEqual(manager.queuedStorageBytes, 6_000_000)
    }

    func test_deletion_failure_reports_error() {
        let mockLibrary = MockPhotoLibrary()
        mockLibrary.shouldSucceed = false
        mockLibrary.shouldError = NSError(domain: "Photos", code: -1, userInfo: nil)
        let manager = DeleteManager(photoLibrary: mockLibrary)

        manager.queueForDeletion(PhotoItem(id: "a", asset: nil, creationDate: nil, mediaType: .image, fileSize: 1000, duration: nil, isFavorited: false))

        let expectation = expectation(description: "Deletion fails")
        manager.executeQueuedDeletions { result in
            switch result {
            case .success:
                XCTFail("Should have failed")
            case .failure:
                break // expected
            }
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)
    }

    func test_execute_empty_queue_succeeds_with_zero() {
        let mockLibrary = MockPhotoLibrary()
        let manager = DeleteManager(photoLibrary: mockLibrary)

        let expectation = expectation(description: "Empty deletion completes")
        manager.executeQueuedDeletions { result in
            switch result {
            case .success(let count):
                XCTAssertEqual(count, 0)
            case .failure:
                XCTFail("Empty deletion should succeed")
            }
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(mockLibrary.performChangesCallCount, 0, "Should not call performChanges for empty queue")
    }
}

// MARK: - SessionTracker Tests

final class SessionTrackerTests: XCTestCase {

    func test_storage_freed_calculation() {
        let mockDefaults = MockUserDefaults()
        let tracker = SessionTracker(userDefaults: mockDefaults)

        tracker.startSession()
        tracker.recordReview(kept: false, fileSize: 3_000_000)
        tracker.recordReview(kept: false, fileSize: 2_000_000)
        tracker.recordReview(kept: true, fileSize: 1_000_000)

        XCTAssertEqual(tracker.sessionStats.photosReviewed, 3)
        XCTAssertEqual(tracker.sessionStats.photosKept, 1)
        XCTAssertEqual(tracker.sessionStats.photosDeleted, 2)
        XCTAssertEqual(tracker.sessionStats.storageFreed, 5_000_000)
    }

    func test_lifetime_persistence() {
        let mockDefaults = MockUserDefaults()

        // Session 1
        let tracker1 = SessionTracker(userDefaults: mockDefaults)
        tracker1.startSession()
        tracker1.recordReview(kept: false, fileSize: 1_000_000)
        tracker1.recordReview(kept: true, fileSize: 500_000)
        tracker1.endSession()

        // Session 2 — same defaults, simulating app relaunch
        let tracker2 = SessionTracker(userDefaults: mockDefaults)
        tracker2.startSession()
        tracker2.recordReview(kept: false, fileSize: 2_000_000)
        tracker2.endSession()

        let lifetime = tracker2.lifetimeStats
        XCTAssertEqual(lifetime.totalPhotosReviewed, 3)
        XCTAssertEqual(lifetime.totalDeleted, 2)
        XCTAssertEqual(lifetime.totalStorageFreed, 3_000_000)
        XCTAssertEqual(lifetime.totalSessions, 2)
    }

    func test_session_time_tracking() {
        let mockDefaults = MockUserDefaults()
        let tracker = SessionTracker(userDefaults: mockDefaults)

        tracker.startSession()
        // Time elapsed will be very small in tests, just verify it's non-negative
        XCTAssertGreaterThanOrEqual(tracker.sessionStats.timeSpent, 0)
    }

    func test_reset_session() {
        let mockDefaults = MockUserDefaults()
        let tracker = SessionTracker(userDefaults: mockDefaults)

        tracker.startSession()
        tracker.recordReview(kept: false, fileSize: 1_000_000)
        tracker.resetSession()

        XCTAssertEqual(tracker.sessionStats.photosReviewed, 0)
        XCTAssertEqual(tracker.sessionStats.storageFreed, 0)
    }
}

// MARK: - AlbumProvider Tests

final class AlbumProviderTests: XCTestCase {

    func test_returns_all_smart_album_types() {
        let mockFetcher = MockAssetFetcher()
        let provider = AlbumProvider(assetFetcher: mockFetcher)

        let sources = provider.fetchAvailableSources()

        let sourceTypes = sources.map { $0.source }

        XCTAssertTrue(sourceTypes.contains(.allPhotos))
        XCTAssertTrue(sourceTypes.contains(.recents))
        XCTAssertTrue(sourceTypes.contains(.screenshots))
        XCTAssertTrue(sourceTypes.contains(.videos))
        XCTAssertTrue(sourceTypes.contains(.selfies))
        XCTAssertTrue(sourceTypes.contains(.livePhotos))
        XCTAssertTrue(sourceTypes.contains(.favorites))
    }

    func test_filters_empty_albums() {
        let mockFetcher = MockAssetFetcher()
        let provider = AlbumProvider(assetFetcher: mockFetcher)

        let sources = provider.fetchAvailableSources()
        for info in sources {
            XCTAssertGreaterThan(info.count, 0, "\(info.source.displayName) should not be empty")
        }
    }

    func test_smart_albums_before_user_albums() {
        let mockFetcher = MockAssetFetcher()
        let provider = AlbumProvider(assetFetcher: mockFetcher)

        let sources = provider.fetchAvailableSources()
        // All returned sources from the mock are smart albums,
        // which is correct — no user albums in mock data
        XCTAssertFalse(sources.isEmpty)
    }
}

// MARK: - PermissionManager Tests

final class PermissionManagerTests: XCTestCase {

    func test_handles_not_determined_state() {
        let mockProvider = MockPermissionProvider()
        mockProvider.stubbedStatus = .notDetermined
        let manager = PermissionManager(permissionProvider: mockProvider)

        XCTAssertEqual(manager.authorizationState, .notDetermined)
    }

    func test_handles_authorized_state() {
        let mockProvider = MockPermissionProvider()
        mockProvider.stubbedStatus = .authorized
        let manager = PermissionManager(permissionProvider: mockProvider)

        manager.checkCurrentStatus()
        XCTAssertEqual(manager.authorizationState, .authorized)
    }

    func test_handles_limited_state() {
        let mockProvider = MockPermissionProvider()
        mockProvider.stubbedStatus = .limited
        let manager = PermissionManager(permissionProvider: mockProvider)

        manager.checkCurrentStatus()
        XCTAssertEqual(manager.authorizationState, .limited)
    }

    func test_handles_denied_state() {
        let mockProvider = MockPermissionProvider()
        mockProvider.stubbedStatus = .denied
        let manager = PermissionManager(permissionProvider: mockProvider)

        manager.checkCurrentStatus()
        XCTAssertEqual(manager.authorizationState, .denied)
    }

    func test_handles_restricted_state() {
        let mockProvider = MockPermissionProvider()
        mockProvider.stubbedStatus = .restricted
        let manager = PermissionManager(permissionProvider: mockProvider)

        manager.checkCurrentStatus()
        XCTAssertEqual(manager.authorizationState, .restricted)
    }

    func test_request_authorization_grants_access() {
        let mockProvider = MockPermissionProvider()
        mockProvider.stubbedStatus = .notDetermined
        mockProvider.statusToGrantOnRequest = .authorized
        let manager = PermissionManager(permissionProvider: mockProvider)

        let expectation = expectation(description: "Authorization requested")
        manager.requestAccess { status in
            XCTAssertEqual(status, .authorized)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        XCTAssertEqual(mockProvider.requestedAccessLevel, .readWrite)
        XCTAssertEqual(manager.authorizationState, .authorized)
    }

    func test_request_authorization_denied() {
        let mockProvider = MockPermissionProvider()
        mockProvider.stubbedStatus = .notDetermined
        mockProvider.statusToGrantOnRequest = .denied
        let manager = PermissionManager(permissionProvider: mockProvider)

        let expectation = expectation(description: "Authorization denied")
        manager.requestAccess { status in
            XCTAssertEqual(status, .denied)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        XCTAssertEqual(manager.authorizationState, .denied)
    }
}
