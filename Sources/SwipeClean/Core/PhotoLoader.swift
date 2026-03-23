import Photos
import UIKit
import Combine

/// Loads photos from a selected AlbumSource with preloading and sliding window pagination.
final class PhotoLoader: ObservableObject {

    // MARK: - Public State

    @Published private(set) var currentPhoto: PhotoItem?
    @Published private(set) var upcomingPhotos: [PhotoItem] = []
    @Published private(set) var currentIndex: Int = 0
    @Published private(set) var totalCount: Int = 0
    @Published private(set) var isLoading: Bool = false

    var progress: Float {
        guard totalCount > 0 else { return 0 }
        return Float(currentIndex) / Float(totalCount)
    }

    /// The number of items currently held in the active window (for testing).
    var activeWindowSize: Int { activeWindow.count }

    // MARK: - Configuration

    static let windowSize = 20
    static let preloadCount = 3
    static let thumbnailSize = CGSize(width: 600, height: 600)

    /// Screen-sized image (1x scale — sharp enough, not wastefully large)
    var displayImageSize: CGSize {
        let bounds = UIScreen.main.bounds
        return CGSize(width: bounds.width, height: bounds.height)
    }

    // MARK: - Private State

    private let imageLoader: ImageLoading
    private let assetFetcher: AssetFetching
    private var allItems: [PhotoItem] = []
    private var activeWindow: [PhotoItem] = []
    private var activeRequestIDs: [String: Set<PHImageRequestID>] = [:]

    // MARK: - Init

    init(
        imageLoader: ImageLoading = PHImageManager.default(),
        assetFetcher: AssetFetching = LiveAssetFetcher()
    ) {
        self.imageLoader = imageLoader
        self.assetFetcher = assetFetcher
    }

    // MARK: - Public API

    /// Loads items directly (used in tests and when items are pre-created).
    func loadItems(_ items: [PhotoItem]) {
        allItems = items
        totalCount = items.count
        currentIndex = 0
        rebuildWindow()
        preloadAround(currentIndex)
    }

    /// Fetches photos from the given album source and loads them.
    func loadSource(_ source: AlbumSource, sortOrder: SortOrder = .newestFirst) {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let assets = self.assetFetcher.fetchAssets(for: source, sortOrder: sortOrder)
            var items = assets.map { PhotoItem(asset: $0) }
            if source == .random {
                items.shuffle()
            }
            DispatchQueue.main.async {
                self.loadItems(items)
                self.isLoading = false
            }
        }
    }

    /// Advances to the next photo. Called after a swipe.
    func advance() {
        guard currentIndex < totalCount - 1 else {
            currentIndex = totalCount
            currentPhoto = nil
            upcomingPhotos = []
            return
        }

        cancelRequestsOutsideWindow()
        currentIndex += 1
        rebuildWindow()
        preloadAround(currentIndex)
    }

    /// Goes back one photo (for undo).
    func goBack() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
        rebuildWindow()
        preloadAround(currentIndex)
    }

    /// Whether all photos have been reviewed.
    var isComplete: Bool {
        currentIndex >= totalCount
    }

    // MARK: - Sliding Window

    private func rebuildWindow() {
        guard !allItems.isEmpty, currentIndex < totalCount else {
            activeWindow = []
            currentPhoto = nil
            upcomingPhotos = []
            return
        }

        let halfWindow = Self.windowSize / 2
        let windowStart = max(0, currentIndex - halfWindow)
        let windowEnd = min(totalCount, currentIndex + halfWindow)
        activeWindow = Array(allItems[windowStart..<windowEnd])

        currentPhoto = allItems[currentIndex]

        let preloadEnd = min(totalCount, currentIndex + 1 + Self.preloadCount)
        if currentIndex + 1 < preloadEnd {
            upcomingPhotos = Array(allItems[(currentIndex + 1)..<preloadEnd])
        } else {
            upcomingPhotos = []
        }
    }

    // MARK: - Image Preloading

    private func preloadAround(_ index: Int) {
        guard index < totalCount else { return }

        // Load display-quality image for current photo
        let current = allItems[index]
        loadDisplayImage(for: current)

        // Preload thumbnails for upcoming cards
        let preloadEnd = min(totalCount, index + 1 + Self.preloadCount)
        for i in (index + 1)..<preloadEnd {
            loadThumbnail(for: allItems[i])
        }
    }

    private func loadDisplayImage(for item: PhotoItem) {
        guard let asset = item.asset else { return }
        // Skip if already loaded at full quality
        if item.fullImage != nil { return }

        // First: fast thumbnail so something shows immediately
        if item.thumbnail == nil {
            loadThumbnail(for: item)
        }

        // Then: high quality display image (non-degraded)
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        options.resizeMode = .exact

        let requestID = imageLoader.requestImage(
            for: asset,
            targetSize: displayImageSize,
            contentMode: .aspectFit,
            options: options
        ) { [weak self, weak item] image, _ in
            DispatchQueue.main.async {
                guard let image = image, let item = item else { return }
                item.fullImage = image
                self?.objectWillChange.send()
            }
        }
        trackRequest(requestID, for: item.id)
    }

    private func loadThumbnail(for item: PhotoItem) {
        guard let asset = item.asset, item.thumbnail == nil else { return }

        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        options.resizeMode = .fast

        let requestID = imageLoader.requestImage(
            for: asset,
            targetSize: Self.thumbnailSize,
            contentMode: .aspectFill,
            options: options
        ) { [weak self, weak item] image, _ in
            DispatchQueue.main.async {
                guard let image = image, let item = item else { return }
                item.thumbnail = image
                self?.objectWillChange.send()
            }
        }
        trackRequest(requestID, for: item.id)
    }

    // MARK: - Request Tracking

    private func trackRequest(_ requestID: PHImageRequestID, for itemID: String) {
        if activeRequestIDs[itemID] == nil {
            activeRequestIDs[itemID] = Set()
        }
        activeRequestIDs[itemID]?.insert(requestID)
    }

    // MARK: - Cancellation

    private func cancelRequestsOutsideWindow() {
        let halfWindow = Self.windowSize / 2
        let windowStart = max(0, currentIndex - halfWindow)
        let windowEnd = min(totalCount, currentIndex + halfWindow)

        let windowIDs = Set((windowStart..<windowEnd).map { allItems[$0].id })
        var toRemove: [String] = []

        for (itemID, requestIDs) in activeRequestIDs {
            if !windowIDs.contains(itemID) {
                for requestID in requestIDs {
                    imageLoader.cancelImageRequest(requestID)
                }
                toRemove.append(itemID)
            }
        }
        for id in toRemove {
            activeRequestIDs.removeValue(forKey: id)
        }
    }
}
