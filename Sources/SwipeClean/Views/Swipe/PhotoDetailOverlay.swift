import SwiftUI
import AVKit
import PhotosUI

/// Full-screen photo detail with pinch-to-zoom, pan, and video playback.
/// Presented via long-press or double-tap on a card.
struct PhotoDetailOverlay: View {
    let photo: PhotoItem

    @Environment(\.dismiss) private var dismiss

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero
    @State private var lastPanOffset: CGSize = .zero
    @State private var dismissOffset: CGFloat = 0
    @State private var showVideoPlayer = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
                .opacity(max(0, 1.0 - abs(dismissOffset) / 300.0))

            // Swipe-to-dismiss wrapper
            VStack {
                photoContent
            }
            .offset(y: dismissOffset)
            .gesture(dismissGesture)

            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.white, .white.opacity(0.3))
                    }
                    .padding(16)
                }
                Spacer()
            }

            // Video play button
            if photo.mediaType == .video {
                Button {
                    showVideoPlayer = true
                } label: {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(.white, .black.opacity(0.4))
                }
            }

            // Live Photo hint badge
            if photo.mediaType == .livePhoto {
                VStack {
                    HStack {
                        Label("LIVE", systemImage: "livephoto")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding(.leading, 16)
                            .padding(.top, 16)
                        Spacer()
                    }
                    Spacer()
                    Text("Touch and hold to play")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.bottom, 24)
                }
            }
        }
        .statusBarHidden(true)
        .sheet(isPresented: $showVideoPlayer) {
            VideoPlayerSheet(asset: photo.asset)
        }
        .onTapGesture {
            if scale == 1.0 {
                dismiss()
            }
        }
    }

    // MARK: - Photo Content

    @ViewBuilder
    private var photoContent: some View {
        if photo.mediaType == .livePhoto, let asset = photo.asset {
            // Live Photos play their motion when long-pressed (native gesture).
            LivePhotoPlayer(asset: asset, fallback: photo.fullImage ?? photo.thumbnail)
                .aspectRatio(contentMode: .fit)
                .scaleEffect(scale)
                .offset(panOffset)
                .gesture(zoomGesture)
                .simultaneousGesture(panGesture)
        } else if let image = photo.fullImage ?? photo.thumbnail {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaleEffect(scale)
                .offset(panOffset)
                .gesture(zoomGesture)
                .simultaneousGesture(panGesture)
        } else {
            ProgressView()
                .tint(.white)
        }
    }

    // MARK: - Gestures

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let newScale = lastScale * value
                scale = min(max(newScale, 1.0), 5.0)
            }
            .onEnded { _ in
                lastScale = scale
                if scale <= 1.0 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        scale = 1.0
                        lastScale = 1.0
                        panOffset = .zero
                        lastPanOffset = .zero
                    }
                }
            }
    }

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > 1.0 else { return }
                panOffset = CGSize(
                    width: lastPanOffset.width + value.translation.width,
                    height: lastPanOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastPanOffset = panOffset
            }
    }

    private var dismissGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale <= 1.0 else { return }
                dismissOffset = value.translation.height
            }
            .onEnded { value in
                guard scale <= 1.0 else { return }
                if abs(dismissOffset) > 150 {
                    dismiss()
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        dismissOffset = 0
                    }
                }
            }
    }
}

// MARK: - Live Photo Player

/// Wraps `PHLivePhotoView` so SwiftUI can display a Live Photo. The user can
/// long-press to play the motion, matching the native Photos app behaviour.
struct LivePhotoPlayer: UIViewRepresentable {
    let asset: PHAsset
    let fallback: UIImage?

    func makeUIView(context: Context) -> PHLivePhotoView {
        let view = PHLivePhotoView()
        view.contentMode = .scaleAspectFit
        view.clipsToBounds = true
        return view
    }

    func updateUIView(_ uiView: PHLivePhotoView, context: Context) {
        // Avoid re-requesting if we already have a Live Photo loaded.
        guard uiView.livePhoto == nil else { return }

        let targetSize = CGSize(width: 1080, height: 1920)
        let options = PHLivePhotoRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true

        PHImageManager.default().requestLivePhoto(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFit,
            options: options
        ) { livePhoto, info in
            guard let livePhoto else { return }
            // Ignore degraded intermediate results.
            if let degraded = info?[PHImageResultIsDegradedKey] as? Bool, degraded { return }
            DispatchQueue.main.async {
                uiView.livePhoto = livePhoto
            }
        }
    }
}

// MARK: - Video Player Sheet

/// Wraps AVPlayerViewController for video playback.
struct VideoPlayerSheet: View {
    let asset: PHAsset?

    @State private var player: AVPlayer?

    var body: some View {
        Group {
            if let player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
                    .onAppear { player.play() }
                    .onDisappear { player.pause() }
            } else {
                ProgressView("Loading video...")
                    .tint(.white)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .task {
            await loadVideo()
        }
    }

    private func loadVideo() async {
        guard let asset else { return }
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
                DispatchQueue.main.async {
                    if let urlAsset = avAsset as? AVURLAsset {
                        self.player = AVPlayer(url: urlAsset.url)
                    } else if let avAsset {
                        let playerItem = AVPlayerItem(asset: avAsset)
                        self.player = AVPlayer(playerItem: playerItem)
                    }
                    continuation.resume()
                }
            }
        }
    }
}
