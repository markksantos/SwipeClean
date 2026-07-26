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

    /// How many items are currently holding a decoded image (for testing).
    var decodedImageCount: Int { decodedItems.count }

    // MARK: - Configuration

    static let windowSize = 20
    static let preloadCount = 3
    static let thumbnailSize = CGSize(width: 600, height: 600)

    /// Card-sized image in *pixels*, resolved once at init.
    ///
    /// PhotoKit measures `targetSize` in pixels, so passing point dimensions asks
    /// for a third of the resolution the card actually draws at and the photo
    /// lands visibly soft on a 3x display. Capped at 2x because the card never
    /// fills the whole screen and 3x of a 6.9" panel is ~11MP per decoded image.
    let displayImageSize: CGSize

    // MARK: - Private State

    private let imageLoader: ImageLoading
    private let assetFetcher: AssetFetching
    private var allItems: [PhotoItem] = []
    private var activeWindow: [PhotoItem] = []
    private var activeRequestIDs: [String: Set<PHImageRequestID>] = [:]
    /// Items currently holding a decoded `UIImage`, so `pruneOutsideWindow()` can
    /// release them without scanning the entire album.
    private var decodedItems: [PhotoItem] = []

    // MARK: - Init

    init(
        imageLoader: ImageLoading = PHImageManager.default(),
        assetFetcher: AssetFetching = LiveAssetFetcher()
    ) {
        self.imageLoader = imageLoader
        self.assetFetcher = assetFetcher
        self.displayImageSize = Self.resolveDisplayImageSize()
    }

    /// Measures the window the app is actually in. `UIScreen.main` is deprecated
    /// and reports the full display rather than the app's share of it in Split
    /// View, so this walks the connected scenes and falls back to 6.9" @3x when
    /// there is no scene at all (unit tests).
    private static func resolveDisplayImageSize() -> CGSize {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
            ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first

        let bounds = (scene?.windows.first { $0.isKeyWindow } ?? scene?.windows.first)?.bounds.size
            ?? CGSize(width: 440, height: 956)
        let scale = min(scene?.screen.scale ?? 3, 2)

        return CGSize(width: bounds.width * scale, height: bounds.height * scale)
    }

    // MARK: - Public API

    /// Loads items directly (used in tests and when items are pre-created).
    func loadItems(_ items: [PhotoItem]) {
        // Switching albums abandons the previous item list, so drop its decoded
        // images and in-flight requests rather than letting them outlive it.
        releaseAllDecodedImages()

        allItems = items
        totalCount = items.count
        currentIndex = 0
        rebuildWindow()
        preloadAround(currentIndex)
    }

    private func releaseAllDecodedImages() {
        for requestIDs in activeRequestIDs.values {
            for requestID in requestIDs {
                imageLoader.cancelImageRequest(requestID)
            }
        }
        activeRequestIDs.removeAll()

        for item in decodedItems {
            item.thumbnail = nil
            item.fullImage = nil
        }
        decodedItems.removeAll()
    }

    /// Fetches photos from the given album source and loads them.
    func loadSource(_ source: AlbumSource, sortOrder: SortOrder = .newestFirst) {
        isLoading = true

        if source == .smartCleanup {
            loadSmartCleanup()
            return
        }

        if source == .autoClean {
            // Load pre-filtered assets from the shared store (populated by AutoCleanView).
            let assets = AutoCleanAssetStore.shared.assets
            let items = assets.map { PhotoItem(asset: $0) }
            loadItems(items)
            isLoading = false
            return
        }

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

    /// Fetches all photos, analyzes them with Vision, and loads only low-quality ones.
    private func loadSmartCleanup() {
        Task {
            let assets = await Task.detached { [assetFetcher] in
                assetFetcher.fetchAssets(for: .allPhotos, sortOrder: .newestFirst)
            }.value

            // Cap at 5000 most recent to keep analysis time reasonable
            let capped = Array(assets.prefix(5000))
            let items = capped.map { PhotoItem(asset: $0) }

            let analyzer = PhotoAnalyzer()
            let scores = await analyzer.analyzeAndRank(items) { _ in }

            // Filter to low-quality (< 0.35) and sort worst-first
            let lowQuality = scores
                .filter { $0.qualityScore < 0.35 }
                .sorted { $0.qualityScore < $1.qualityScore }
                .map { $0.item }

            await MainActor.run {
                self.loadItems(lowQuality)
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
            pruneOutsideWindow()
            return
        }

        currentIndex += 1
        rebuildWindow()
        // Prune *after* moving, so the window being pruned against is the one we
        // just moved into rather than the one we left.
        pruneOutsideWindow()
        preloadAround(currentIndex)
    }

    /// Goes back one photo (for undo).
    func goBack() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
        rebuildWindow()
        pruneOutsideWindow()
        preloadAround(currentIndex)
    }

    /// Whether all photos have been reviewed.
    var isComplete: Bool {
        currentIndex >= totalCount
    }

    // MARK: - Sliding Window

    /// Index range of items allowed to hold decoded images and in-flight requests.
    private var windowRange: Range<Int> {
        guard totalCount > 0 else { return 0..<0 }
        let halfWindow = Self.windowSize / 2
        let start = max(0, min(currentIndex, totalCount) - halfWindow)
        let end = min(totalCount, currentIndex + halfWindow)
        return start..<max(start, end)
    }

    private func rebuildWindow() {
        guard !allItems.isEmpty, currentIndex < totalCount else {
            activeWindow = []
            currentPhoto = nil
            upcomingPhotos = []
            return
        }

        activeWindow = Array(allItems[windowRange])

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
                guard let image, let item else { return }
                self?.store(image, on: item, keyPath: \.fullImage)
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
                guard let image, let item else { return }
                self?.store(image, on: item, keyPath: \.thumbnail)
            }
        }
        trackRequest(requestID, for: item.id)
    }

    /// Stores a decoded image on an item and republishes.
    ///
    /// `PhotoItem` is a reference type held inside `@Published` arrays, so
    /// mutating it does not itself invalidate any view — the change has to be
    /// announced by hand, and `objectWillChange` has to fire *before* the write
    /// for SwiftUI to pick up the new value in the same update.
    func store(
        _ image: UIImage,
        on item: PhotoItem,
        keyPath: ReferenceWritableKeyPath<PhotoItem, UIImage?>
    ) {
        objectWillChange.send()
        item[keyPath: keyPath] = image
        if !decodedItems.contains(where: { $0 === item }) {
            decodedItems.append(item)
        }
    }

    // MARK: - Request Tracking

    private func trackRequest(_ requestID: PHImageRequestID, for itemID: String) {
        if activeRequestIDs[itemID] == nil {
            activeRequestIDs[itemID] = Set()
        }
        activeRequestIDs[itemID]?.insert(requestID)
    }

    // MARK: - Window Pruning

    /// Cancels in-flight requests **and releases decoded images** for every item
    /// outside the active window.
    ///
    /// `allItems` holds one `PhotoItem` per asset in the album — tens of thousands
    /// on a real library — and `PhotoItem` is a class, so a screen-sized
    /// `UIImage` assigned during review stays alive for the whole session unless
    /// it is explicitly dropped. Without this the app grows by a few megabytes
    /// per swipe and gets jetsammed after a few hundred cards.
    private func pruneOutsideWindow() {
        let window = windowRange
        let windowIDs = Set(allItems[window].map(\.id))

        for (itemID, requestIDs) in activeRequestIDs where !windowIDs.contains(itemID) {
            for requestID in requestIDs {
                imageLoader.cancelImageRequest(requestID)
            }
            activeRequestIDs.removeValue(forKey: itemID)
        }

        // Walk only the items known to be holding images rather than the whole
        // album, so the cost of a swipe stays flat as the library grows.
        for item in decodedItems where !windowIDs.contains(item.id) {
            item.thumbnail = nil
            item.fullImage = nil
        }
        decodedItems.removeAll { !windowIDs.contains($0.id) }
    }
}
