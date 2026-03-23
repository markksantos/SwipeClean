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

        case .onThisDay:
            let calendar = Calendar.current
            let today = Date()
            let month = calendar.component(.month, from: today)
            let day = calendar.component(.day, from: today)
            // Fetch photos from any year on this month/day
            var predicates: [NSPredicate] = []
            for yearOffset in 1...20 {
                guard let targetDate = calendar.date(byAdding: .year, value: -yearOffset, to: today) else { continue }
                let year = calendar.component(.year, from: targetDate)
                var startComps = DateComponents()
                startComps.year = year
                startComps.month = month
                startComps.day = day
                var endComps = startComps
                endComps.day = day + 1
                guard let start = calendar.date(from: startComps),
                      let end = calendar.date(from: endComps) else { continue }
                predicates.append(NSPredicate(format: "creationDate >= %@ AND creationDate < %@", start as NSDate, end as NSDate))
            }
            if !predicates.isEmpty {
                options.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
            }
            fetchResult = PHAsset.fetchAssets(with: options)

        case .random:
            fetchResult = PHAsset.fetchAssets(with: options)

        case .month(let year, let month):
            let calendar = Calendar.current
            var startComps = DateComponents()
            startComps.year = year
            startComps.month = month
            startComps.day = 1
            guard let start = calendar.date(from: startComps),
                  let end = calendar.date(byAdding: .month, value: 1, to: start) else {
                fetchResult = PHAsset.fetchAssets(with: PHFetchOptions())
                break
            }
            options.predicate = NSPredicate(format: "creationDate >= %@ AND creationDate < %@", start as NSDate, end as NSDate)
            fetchResult = PHAsset.fetchAssets(with: options)

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
            (.onThisDay, nil),
            (.random, nil),
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
            case .onThisDay:
                let calendar = Calendar.current
                let today = Date()
                let month = calendar.component(.month, from: today)
                let day = calendar.component(.day, from: today)
                var predicates: [NSPredicate] = []
                for yearOffset in 1...20 {
                    guard let targetDate = calendar.date(byAdding: .year, value: -yearOffset, to: today) else { continue }
                    let year = calendar.component(.year, from: targetDate)
                    var startComps = DateComponents()
                    startComps.year = year
                    startComps.month = month
                    startComps.day = day
                    var endComps = startComps
                    endComps.day = day + 1
                    guard let start = calendar.date(from: startComps),
                          let end = calendar.date(from: endComps) else { continue }
                    predicates.append(NSPredicate(format: "creationDate >= %@ AND creationDate < %@", start as NSDate, end as NSDate))
                }
                if !predicates.isEmpty {
                    let opts = PHFetchOptions()
                    opts.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
                    count = PHAsset.fetchAssets(with: opts).count
                } else {
                    count = 0
                }
            case .random:
                count = PHAsset.fetchAssets(with: nil).count
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

        // User-created albums — fetch all subtypes
        let albumSubtypes: [PHAssetCollectionSubtype] = [
            .albumRegular,
            .albumSyncedEvent,
            .albumSyncedFaces,
            .albumSyncedAlbum,
            .albumImported,
            .albumCloudShared,
            .any
        ]
        var seenAlbumIDs = Set<String>()
        var userResults: [AlbumSourceInfo] = []
        for subtype in albumSubtypes {
            let userAlbums = PHAssetCollection.fetchAssetCollections(
                with: .album, subtype: subtype, options: nil
            )
            userAlbums.enumerateObjects { collection, _, _ in
                guard !seenAlbumIDs.contains(collection.localIdentifier) else { return }
                seenAlbumIDs.insert(collection.localIdentifier)
                let assetCount = PHAsset.fetchAssets(in: collection, options: nil).count
                if assetCount > 0 {
                    userResults.append(AlbumSourceInfo(source: .album(collection), count: assetCount))
                }
            }
        }
        // Sort user albums alphabetically
        userResults.sort { ($0.source.displayName) < ($1.source.displayName) }
        results.append(contentsOf: userResults)

        // Month-based sources — find months that have photos
        let calendar = Calendar.current
        let allAssets = PHAsset.fetchAssets(with: nil)
        var monthCounts: [String: (year: Int, month: Int, count: Int)] = [:]
        allAssets.enumerateObjects { asset, _, _ in
            guard let date = asset.creationDate else { return }
            let year = calendar.component(.year, from: date)
            let month = calendar.component(.month, from: date)
            let key = "\(year)-\(month)"
            if let existing = monthCounts[key] {
                monthCounts[key] = (year, month, existing.count + 1)
            } else {
                monthCounts[key] = (year, month, 1)
            }
        }
        // Sort months newest first, take top 12
        let sortedMonths = monthCounts.values.sorted { a, b in
            if a.year != b.year { return a.year > b.year }
            return a.month > b.month
        }
        for entry in sortedMonths.prefix(12) {
            results.append(AlbumSourceInfo(
                source: .month(entry.year, entry.month),
                count: entry.count
            ))
        }

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
    @Published private(set) var isLoading: Bool = false

    private let assetFetcher: AssetFetching

    init(assetFetcher: AssetFetching = LiveAssetFetcher()) {
        self.assetFetcher = assetFetcher
    }

    /// Fetches all available sources synchronously on the calling thread.
    /// Smart albums appear first, then user albums alphabetically.
    func fetchAvailableSources() -> [AlbumSourceInfo] {
        let fetched = assetFetcher.fetchAlbumSources()
        sources = fetched
        return fetched
    }

    /// Fetches available sources on a background queue and publishes results on main.
    /// Sets `isLoading` while the fetch is in progress.
    func fetchAvailableSourcesAsync() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let fetched = self?.assetFetcher.fetchAlbumSources() ?? []
            DispatchQueue.main.async {
                self?.sources = fetched
                self?.isLoading = false
            }
        }
    }
}
