import AVFoundation
import Photos
import UIKit

/// Produces the real file behind a photo library item so "share before delete"
/// hands over the original rather than a copy.
///
/// The swipe screen used to share `PhotoItem.fullImage` — a card-sized `UIImage`
/// decoded for display. Sharing that sends a downscaled, re-encoded image with no
/// EXIF, and sends nothing at all when the card is still loading. Both matter
/// here: the whole point of the button is to rescue a photo before it is deleted.
enum ShareItemLoader {

    /// Writes the item's original data to a temporary file and returns its URL.
    /// Falls back to any already-decoded image if the original is unavailable.
    static func item(for photo: PhotoItem) async -> Any? {
        guard let asset = photo.asset else { return photo.fullImage ?? photo.thumbnail }

        if asset.mediaType == .video {
            return await videoURL(for: asset)
        }
        if let url = await imageURL(for: asset) {
            return url
        }
        return photo.fullImage ?? photo.thumbnail
    }

    // MARK: - Images

    private static func imageURL(for asset: PHAsset) async -> URL? {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        options.isSynchronous = false
        options.version = .current

        let payload: (Data, String)? = await withCheckedContinuation { continuation in
            PHImageManager.default().requestImageDataAndOrientation(
                for: asset,
                options: options
            ) { data, uti, _, _ in
                guard let data else { return continuation.resume(returning: nil) }
                continuation.resume(returning: (data, uti ?? "public.jpeg"))
            }
        }

        guard let (data, uti) = payload else { return nil }
        let name = "\(filenameStem(for: asset)).\(fileExtension(forUTI: uti))"
        return write(data, named: name)
    }

    // MARK: - Videos

    private static func videoURL(for asset: PHAsset) async -> Any? {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        options.version = .current

        let avAsset: AVAsset? = await withCheckedContinuation { continuation in
            PHImageManager.default().requestAVAsset(
                forVideo: asset,
                options: options
            ) { avAsset, _, _ in
                continuation.resume(returning: avAsset)
            }
        }

        // A local video is already a file on disk, which the share sheet can hand
        // straight to another app. Composed or slow-motion assets are not, and
        // exporting them would be a long job with its own progress UI — out of
        // scope for a share button, so those simply are not shareable this way.
        return (avAsset as? AVURLAsset)?.url
    }

    // MARK: - Helpers

    private static func write(_ data: Data, named name: String) -> URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("share", isDirectory: true)
            .appendingPathComponent(name)
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    /// A readable stem so the shared file is not called `IMG_0000`-with-a-UUID.
    private static func filenameStem(for asset: PHAsset) -> String {
        guard let date = asset.creationDate else { return "photo" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter.string(from: date)
    }

    private static func fileExtension(forUTI uti: String) -> String {
        switch uti {
        case "public.heic", "public.heif": return "heic"
        case "public.png": return "png"
        case "com.compuserve.gif": return "gif"
        case "public.tiff": return "tiff"
        case "org.webmproject.webp", "public.webp": return "webp"
        default: return "jpg"
        }
    }
}
