import Photos

/// A group of similar photos taken within a short time window.
struct SimilarPhotoGroup: Identifiable {
    let id = UUID()
    var photos: [PhotoScore]  // Sorted by quality, best first

    var bestPhoto: PhotoScore? { photos.first }
    var count: Int { photos.count }
}

/// Finds groups of similar photos by time proximity and scores them with PhotoAnalyzer.
final class SimilarPhotoFinder {

    private let analyzer = PhotoAnalyzer()
    private let assetFetcher: AssetFetching

    /// Maximum seconds between consecutive photos to consider them similar.
    private let timeWindow: TimeInterval = 10

    init(assetFetcher: AssetFetching = LiveAssetFetcher()) {
        self.assetFetcher = assetFetcher
    }

    // MARK: - Public API

    /// Finds groups of similar photos from the entire library.
    /// Returns groups of 2+ photos sorted by quality (best first in each group).
    /// Progress callback reports 0-1 across two phases: grouping (~10%) and scoring (~90%).
    func findSimilarGroups(
        progress: @escaping (Float, String) -> Void
    ) async -> [SimilarPhotoGroup] {
        progress(0, "Scanning photo library...")

        // Fetch all photos sorted by creation date
        let assets = assetFetcher.fetchAssets(for: .allPhotos, sortOrder: .oldestFirst)

        guard assets.count >= 2 else { return [] }

        progress(0.05, "Grouping \(assets.count) photos by time...")

        // Group consecutive photos within the time window
        let rawGroups = groupByTime(assets)

        guard !rawGroups.isEmpty else { return [] }

        progress(0.10, "Analyzing \(rawGroups.count) groups...")

        // Analyze each group with PhotoAnalyzer
        let totalPhotos = rawGroups.reduce(0) { $0 + $1.count }
        var analyzed = 0
        var result: [SimilarPhotoGroup] = []

        for group in rawGroups {
            let items = group.map { PhotoItem(asset: $0) }
            let scores = await analyzer.analyzeAndRank(items) { _ in }

            analyzed += group.count
            let pct = 0.10 + 0.90 * Float(analyzed) / Float(totalPhotos)
            progress(pct, "Analyzing photos... \(analyzed)/\(totalPhotos)")

            result.append(SimilarPhotoGroup(photos: scores))
        }

        progress(1.0, "Done! Found \(result.count) groups.")
        return result
    }

    // MARK: - Private

    /// Groups consecutive assets whose creation dates are within `timeWindow` seconds.
    /// Only returns groups with 2+ photos.
    private func groupByTime(_ assets: [PHAsset]) -> [[PHAsset]] {
        var groups: [[PHAsset]] = []
        var currentGroup: [PHAsset] = []

        for asset in assets {
            guard let date = asset.creationDate else {
                // Flush current group and skip dateless assets
                if currentGroup.count >= 2 {
                    groups.append(currentGroup)
                }
                currentGroup = []
                continue
            }

            if let lastAsset = currentGroup.last,
               let lastDate = lastAsset.creationDate {
                let interval = date.timeIntervalSince(lastDate)
                if interval <= timeWindow {
                    currentGroup.append(asset)
                } else {
                    if currentGroup.count >= 2 {
                        groups.append(currentGroup)
                    }
                    currentGroup = [asset]
                }
            } else {
                currentGroup = [asset]
            }
        }

        // Don't forget the last group
        if currentGroup.count >= 2 {
            groups.append(currentGroup)
        }

        return groups
    }
}
