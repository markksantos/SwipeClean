import UIKit
import Photos

/// The media type of a photo library item.
enum PhotoMediaType: String, Equatable, Codable {
    case image
    case video
    case screenshot
    case livePhoto
}

/// A lightweight wrapper around PHAsset that holds preloaded data the UI needs.
final class PhotoItem: Identifiable {
    let id: String
    let asset: PHAsset?
    var thumbnail: UIImage?
    var fullImage: UIImage?
    let creationDate: Date?
    let mediaType: PhotoMediaType
    let fileSize: Int64
    let duration: TimeInterval?
    let isFavorited: Bool

    init(
        id: String,
        asset: PHAsset?,
        thumbnail: UIImage? = nil,
        fullImage: UIImage? = nil,
        creationDate: Date?,
        mediaType: PhotoMediaType,
        fileSize: Int64,
        duration: TimeInterval?,
        isFavorited: Bool
    ) {
        self.id = id
        self.asset = asset
        self.thumbnail = thumbnail
        self.fullImage = fullImage
        self.creationDate = creationDate
        self.mediaType = mediaType
        self.fileSize = fileSize
        self.duration = duration
        self.isFavorited = isFavorited
    }

    /// Creates a PhotoItem from a PHAsset, computing media type and fetching resource metadata.
    convenience init(asset: PHAsset) {
        let mediaType: PhotoMediaType = {
            if asset.mediaType == .video {
                return .video
            }
            if asset.mediaSubtypes.contains(.photoLive) {
                return .livePhoto
            }
            if asset.mediaSubtypes.contains(.photoScreenshot) {
                return .screenshot
            }
            return .image
        }()

        let resources = PHAssetResource.assetResources(for: asset)
        let fileSize: Int64 = resources.reduce(0) { total, resource in
            let size = resource.value(forKey: "fileSize") as? Int64 ?? 0
            return total + size
        }

        self.init(
            id: asset.localIdentifier,
            asset: asset,
            creationDate: asset.creationDate,
            mediaType: mediaType,
            fileSize: fileSize,
            duration: asset.mediaType == .video ? asset.duration : nil,
            isFavorited: asset.isFavorite
        )
    }
}
