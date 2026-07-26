import Photos
import SwiftUI

/// A grid-cell thumbnail that loads straight from PhotoKit and releases the image
/// when the cell scrolls away.
///
/// Grids must not read `PhotoItem.thumbnail`: that field only holds an image
/// while the item sits inside `PhotoLoader`'s active window, so cells for
/// anything else — every photo already queued for deletion, every album the user
/// has not swiped through — would draw a placeholder. Requesting per cell also
/// means a 500-photo queue costs only the handful of thumbnails on screen
/// instead of 500 decoded images held for the session.
struct AssetThumbnailView: View {
    let asset: PHAsset?
    /// Longest edge in points; the request is made at the matching pixel size.
    var side: CGFloat = 130
    /// Grid cells crop to a square; a single large preview must show the whole
    /// frame instead, or portrait photos lose their top and bottom.
    var fills: Bool = true

    @Environment(\.displayScale) private var displayScale

    @State private var image: UIImage?
    @State private var requestID: PHImageRequestID?

    private var pixelSide: CGFloat { side * displayScale }

    var body: some View {
        Group {
            if fills {
                Rectangle()
                    .fill(Color(.tertiarySystemGroupedBackground))
                    .overlay { content.scaledToFill() }
                    .clipped()
            } else {
                content.scaledToFit()
            }
        }
        .task(id: asset?.localIdentifier) { await load() }
        .onDisappear(perform: cancel)
    }

    @ViewBuilder
    private var content: some View {
        if let image {
            Image(uiImage: image).resizable()
        } else {
            Image(systemName: "photo")
                .resizable()
                .foregroundStyle(.tertiary)
                .padding(fills ? 24 : 120)
        }
    }

    private func load() async {
        guard let asset, image == nil else { return }

        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true

        // `requestImage` can call back more than once with `.opportunistic` (a
        // fast degraded image, then the good one), so this is a stream of
        // updates rather than a single continuation.
        requestID = PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: pixelSide, height: pixelSide),
            contentMode: .aspectFill,
            options: options
        ) { result, _ in
            guard let result else { return }
            Task { @MainActor in image = result }
        }
    }

    private func cancel() {
        if let requestID {
            PHImageManager.default().cancelImageRequest(requestID)
        }
        requestID = nil
        image = nil
    }
}
