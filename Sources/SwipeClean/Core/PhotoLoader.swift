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

    var fullImageSize: CGSize {
        let screen = UIScreen.main
        let scale = screen.scale
        let bounds = screen.bounds
        return CGSize(width: bounds.width * scale, height: bounds.height * scale)
    }

    // MARK: - Private State

    private let imageLoader: ImageLoading
    private let assetFetcher: AssetFetching
    private var allItems: [PhotoItem] = []
    private var activeWindow: [PhotoItem] = []
    private var activeRequestIDs: [String: PHImageRequestID] = [:]

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
        let assets = assetFetcher.fetchAssets(for: source, sortOrder: sortOrder)
        let items = assets.map { PhotoItem(asset: $0) }
        loadItems(items)
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

        // Load full-res for current
        let current = allItems[index]
        loadFullImage(for: current)

        // Load thumbnails for upcoming
        let preloadEnd = min(totalCount, index + 1 + Self.preloadCount)
        for i in (index + 1)..<preloadEnd {
            loadThumbnail(for: allItems[i])
        }
    }

    private func loadFullImage(for item: PhotoItem) {
        guard let asset = item.asset else { return }

        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        options.resizeMode = .fast

        let requestID = imageLoader.requestImage(
            for: asset,
            targetSize: fullImageSize,
            contentMode: .aspectFit,
            options: options
        ) { [weak item] image, info in
            let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
            if let image = image {
                item?.fullImage = image
                if !isDegraded {
                    item?.thumbnail = item?.thumbnail ?? image
                }
            }
        }
        activeRequestIDs[item.id] = requestID
    }

    private func loadThumbnail(for item: PhotoItem) {
        guard let asset = item.asset, item.thumbnail == nil else { return }

        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        options.resizeMode = .fast

        let requestID = imageLoader.requestImage(
            for: asset,
            targetSize: Self.thumbnailSize,
            contentMode: .aspectFill,
            options: options
        ) { [weak item] image, _ in
            if let image = image {
                item?.thumbnail = image
            }
        }
        activeRequestIDs[item.id] = requestID
    }

    // MARK: - Cancellation

    private func cancelRequestsOutsideWindow() {
        let halfWindow = Self.windowSize / 2
        let windowStart = max(0, currentIndex - halfWindow)
        let windowEnd = min(totalCount, currentIndex + halfWindow)

        let windowIDs = Set((windowStart..<windowEnd).map { allItems[$0].id })
        var toRemove: [String] = []

        for (itemID, requestID) in activeRequestIDs {
            if !windowIDs.contains(itemID) {
                imageLoader.cancelImageRequest(requestID)
                toRemove.append(itemID)
            }
        }
        for id in toRemove {
            activeRequestIDs.removeValue(forKey: id)
        }
    }
}
