import Photos

/// Production implementation of AssetFetching.
final class LiveAssetFetcher: AssetFetching {

    func fetchAssets(for source: AlbumSource, sortOrder: SortOrder) -> [PHAsset] {
        let options = PHFetchOptions()
        options.sortDescriptors = [
            NSSortDescriptor(key: "creationDate", ascending: sortOrder == .oldestFirst)
        ]

        let fetchResult: PHFetchResult<PHAsset>

        switch source {
        case .allPhotos:
            fetchResult = PHAsset.fetchAssets(with: options)

        case .recents:
            let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            options.predicate = NSPredicate(format: "creationDate >= %@", thirtyDaysAgo as NSDate)
            fetchResult = PHAsset.fetchAssets(with: options)

        case .screenshots:
            fetchResult = fetchSmartAlbum(.smartAlbumScreenshots, options: options)

        case .videos:
            fetchResult = fetchSmartAlbum(.smartAlbumVideos, options: options)

        case .selfies:
            fetchResult = fetchSmartAlbum(.smartAlbumSelfPortraits, options: options)

        case .livePhotos:
            fetchResult = fetchSmartAlbum(.smartAlbumLivePhotos, options: options)

        case .favorites:
            fetchResult = fetchSmartAlbum(.smartAlbumUserLibrary, options: options, predicate: NSPredicate(format: "isFavorite == YES"))

        case .album(let collection):
            fetchResult = PHAsset.fetchAssets(in: collection, options: options)

        case .duplicates:
            // Fetch all photos and group by burst identifier for basic duplicate detection.
            options.predicate = NSPredicate(format: "burstIdentifier != nil")
            fetchResult = PHAsset.fetchAssets(with: options)
        }

        var assets: [PHAsset] = []
        assets.reserveCapacity(fetchResult.count)
        fetchResult.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        return assets
    }

    func fetchAlbumSources() -> [AlbumSourceInfo] {
        var results: [AlbumSourceInfo] = []

        // Smart albums in display order
        let smartSources: [(AlbumSource, PHAssetCollectionSubtype?)] = [
            (.allPhotos, nil),
            (.recents, nil),
            (.screenshots, .smartAlbumScreenshots),
            (.videos, .smartAlbumVideos),
            (.selfies, .smartAlbumSelfPortraits),
            (.livePhotos, .smartAlbumLivePhotos),
            (.favorites, nil),
            (.duplicates, nil),
        ]

        for (source, subtype) in smartSources {
            let count: Int
            switch source {
            case .allPhotos:
                count = PHAsset.fetchAssets(with: nil).count
            case .recents:
                let opts = PHFetchOptions()
                let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
                opts.predicate = NSPredicate(format: "creationDate >= %@", thirtyDaysAgo as NSDate)
                count = PHAsset.fetchAssets(with: opts).count
            case .favorites:
                let opts = PHFetchOptions()
                opts.predicate = NSPredicate(format: "isFavorite == YES")
                count = PHAsset.fetchAssets(with: opts).count
            case .duplicates:
                let opts = PHFetchOptions()
                opts.predicate = NSPredicate(format: "burstIdentifier != nil")
                count = PHAsset.fetchAssets(with: opts).count
            default:
                if let subtype = subtype {
                    let collections = PHAssetCollection.fetchAssetCollections(
                        with: .smartAlbum, subtype: subtype, options: nil
                    )
                    if let collection = collections.firstObject {
                        count = PHAsset.fetchAssets(in: collection, options: nil).count
                    } else {
                        count = 0
                    }
                } else {
                    count = 0
                }
            }

            if count > 0 {
                results.append(AlbumSourceInfo(source: source, count: count))
            }
        }

        // User-created albums
        let userAlbums = PHAssetCollection.fetchAssetCollections(
            with: .album, subtype: .albumRegular, options: nil
        )
        var userResults: [AlbumSourceInfo] = []
        userAlbums.enumerateObjects { collection, _, _ in
            let assetCount = PHAsset.fetchAssets(in: collection, options: nil).count
            if assetCount > 0 {
                userResults.append(AlbumSourceInfo(source: .album(collection), count: assetCount))
            }
        }
        // Sort user albums alphabetically
        userResults.sort { ($0.source.displayName) < ($1.source.displayName) }
        results.append(contentsOf: userResults)

        return results
    }

    // MARK: - Helpers

    private func fetchSmartAlbum(
        _ subtype: PHAssetCollectionSubtype,
        options: PHFetchOptions,
        predicate: NSPredicate? = nil
    ) -> PHFetchResult<PHAsset> {
        let collections = PHAssetCollection.fetchAssetCollections(
            with: .smartAlbum, subtype: subtype, options: nil
        )
        guard let collection = collections.firstObject else {
            return PHAsset.fetchAssets(with: PHFetchOptions()) // empty result
        }
        if let predicate = predicate {
            options.predicate = predicate
        }
        return PHAsset.fetchAssets(in: collection, options: options)
    }
}

/// Fetches available album sources for the source picker UI.
final class AlbumProvider: ObservableObject {

    @Published private(set) var sources: [AlbumSourceInfo] = []

    private let assetFetcher: AssetFetching

    init(assetFetcher: AssetFetching = LiveAssetFetcher()) {
        self.assetFetcher = assetFetcher
    }

    /// Fetches all available sources, filtering out empty ones.
    /// Smart albums appear first, then user albums alphabetically.
    func fetchAvailableSources() -> [AlbumSourceInfo] {
        let fetched = assetFetcher.fetchAlbumSources()
        sources = fetched
        return fetched
    }
}
