import Photos
import UIKit
import Vision

/// Fetches PHAssets matching the user's enabled cleanup rules.
final class CleanupRuleEngine {

    /// Result containing matched assets and estimated storage.
    struct MatchResult {
        let assets: [PHAsset]
        let estimatedBytes: Int64
    }

    /// Runs all enabled rules and returns the deduplicated union of matching assets.
    /// Progress callback receives values from 0.0 to 1.0.
    func findMatches(
        for rules: [CleanupRule],
        progress: @escaping (Double) -> Void
    ) async -> MatchResult {
        let enabledRules = rules.filter(\.isEnabled)
        guard !enabledRules.isEmpty else {
            return MatchResult(assets: [], estimatedBytes: 0)
        }

        var allAssets: [PHAsset] = []
        var seenIDs = Set<String>()
        let totalRules = Double(enabledRules.count)

        for (index, rule) in enabledRules.enumerated() {
            let ruleAssets = await fetchAssets(for: rule)
            for asset in ruleAssets {
                if seenIDs.insert(asset.localIdentifier).inserted {
                    allAssets.append(asset)
                }
            }
            await MainActor.run {
                progress(Double(index + 1) / totalRules)
            }
        }

        let estimatedBytes = estimateStorage(for: allAssets)
        return MatchResult(assets: allAssets, estimatedBytes: estimatedBytes)
    }

    // MARK: - Per-Rule Fetching

    private func fetchAssets(for rule: CleanupRule) async -> [PHAsset] {
        switch rule.id {
        case "old_screenshots":
            return fetchOldScreenshots()
        case "large_videos":
            return await fetchLargeVideos()
        case "old_no_faces":
            return await fetchOldPhotosWithoutFaces()
        case "burst_photos":
            return fetchBurstPhotos()
        case "old_live_photos":
            return fetchOldLivePhotos()
        default:
            return []
        }
    }

    /// Screenshots older than 6 months.
    private func fetchOldScreenshots() -> [PHAsset] {
        let options = PHFetchOptions()
        let sixMonthsAgo = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
        options.predicate = NSPredicate(
            format: "mediaSubtype == %d AND creationDate < %@",
            PHAssetMediaSubtype.photoScreenshot.rawValue,
            sixMonthsAgo as NSDate
        )
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        return enumerateResult(PHAsset.fetchAssets(with: options))
    }

    /// Videos larger than 100 MB — fetch all videos, then filter by resource size.
    private func fetchLargeVideos() async -> [PHAsset] {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let allVideos = enumerateResult(PHAsset.fetchAssets(with: options))

        let threshold: Int64 = 100 * 1024 * 1024 // 100 MB
        return allVideos.filter { asset in
            let resources = PHAssetResource.assetResources(for: asset)
            for resource in resources {
                if let fileSize = resource.value(forKey: "fileSize") as? Int64, fileSize > threshold {
                    return true
                }
            }
            return false
        }
    }

    /// Photos older than 1 year with no detected faces.
    private func fetchOldPhotosWithoutFaces() async -> [PHAsset] {
        let options = PHFetchOptions()
        let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
        options.predicate = NSPredicate(
            format: "mediaType == %d AND creationDate < %@",
            PHAssetMediaType.image.rawValue,
            oneYearAgo as NSDate
        )
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        // Cap to keep analysis time reasonable
        options.fetchLimit = 500
        let candidates = enumerateResult(PHAsset.fetchAssets(with: options))

        var noFaceAssets: [PHAsset] = []
        for asset in candidates {
            let hasFaces = await detectFaces(in: asset)
            if !hasFaces {
                noFaceAssets.append(asset)
            }
        }
        return noFaceAssets
    }

    /// Burst photos (assets with a burst identifier).
    private func fetchBurstPhotos() -> [PHAsset] {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "burstIdentifier != nil")
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        return enumerateResult(PHAsset.fetchAssets(with: options))
    }

    /// Live Photos older than 6 months.
    private func fetchOldLivePhotos() -> [PHAsset] {
        let options = PHFetchOptions()
        let sixMonthsAgo = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
        options.predicate = NSPredicate(
            format: "mediaSubtype == %d AND creationDate < %@",
            PHAssetMediaSubtype.photoLive.rawValue,
            sixMonthsAgo as NSDate
        )
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        return enumerateResult(PHAsset.fetchAssets(with: options))
    }

    // MARK: - Helpers

    private func enumerateResult(_ fetchResult: PHFetchResult<PHAsset>) -> [PHAsset] {
        var assets: [PHAsset] = []
        assets.reserveCapacity(fetchResult.count)
        fetchResult.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        return assets
    }

    private func estimateStorage(for assets: [PHAsset]) -> Int64 {
        var total: Int64 = 0
        for asset in assets {
            let resources = PHAssetResource.assetResources(for: asset)
            for resource in resources {
                if let fileSize = resource.value(forKey: "fileSize") as? Int64 {
                    total += fileSize
                    break // Count primary resource only
                }
            }
        }
        return total
    }

    /// Detects faces in a PHAsset using Vision framework.
    private func detectFaces(in asset: PHAsset) async -> Bool {
        guard let cgImage = await loadCGImage(for: asset) else { return false }
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            if let results = request.results, !results.isEmpty {
                return true
            }
        } catch {}
        return false
    }

    private func loadCGImage(for asset: PHAsset) async -> CGImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .fastFormat
            options.isNetworkAccessAllowed = false
            options.isSynchronous = true
            options.resizeMode = .fast

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 300, height: 300),
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                continuation.resume(returning: image?.cgImage)
            }
        }
    }
}
