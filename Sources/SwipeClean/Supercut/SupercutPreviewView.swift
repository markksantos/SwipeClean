import SwiftUI
import AVKit
import Photos

/// Previews a generated supercut video with options to save, share, or regenerate.
struct SupercutPreviewView: View {
    let videoURL: URL
    let onSave: () -> Void
    let onShare: () -> Void
    let onRegenerate: () -> Void
    let onDismiss: () -> Void

    @State private var player: AVPlayer?
    @State private var isSaving = false
    @State private var saveComplete = false
    @State private var saveError: String?
    @State private var showShareSheet = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Video player
                if let player {
                    VideoPlayer(player: player)
                        .aspectRatio(9 / 16, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                } else {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .aspectRatio(9 / 16, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                }

                Spacer(minLength: 16)

                // Error message
                if let saveError {
                    Text(saveError)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, 24)
                }

                // Action buttons
                VStack(spacing: 12) {
                    // Save to Photos
                    Button {
                        saveToPhotos()
                    } label: {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: saveComplete ? "checkmark" : "square.and.arrow.down.fill")
                                Text(saveComplete ? "Saved" : "Save to Photos")
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(saveComplete ? Color.green : Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(isSaving || saveComplete)

                    HStack(spacing: 12) {
                        // Share
                        Button {
                            showShareSheet = true
                            onShare()
                        } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share")
                            }
                            .font(.headline)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Color(.systemGray5))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        // Regenerate
                        Button {
                            onRegenerate()
                        } label: {
                            HStack {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Redo")
                            }
                            .font(.headline)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Color(.systemGray5))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        player?.pause()
                        onDismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(activityItems: [videoURL])
            }
            .onAppear {
                setupPlayer()
            }
            .onDisappear {
                player?.pause()
                NotificationCenter.default.removeObserver(self)
            }
        }
    }

    // MARK: - Player Setup

    private func setupPlayer() {
        let avPlayer = AVPlayer(url: videoURL)
        player = avPlayer
        avPlayer.play()

        // Loop playback.
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: avPlayer.currentItem,
            queue: .main
        ) { _ in
            avPlayer.seek(to: .zero)
            avPlayer.play()
        }
    }

    // MARK: - Save to Photos

    private func saveToPhotos() {
        isSaving = true
        saveError = nil

        PHPhotoLibrary.shared().performChanges {
            PHAssetCreationRequest.forAsset().addResource(with: .video, fileURL: videoURL, options: nil)
        } completionHandler: { success, error in
            DispatchQueue.main.async {
                isSaving = false
                if success {
                    saveComplete = true
                    onSave()
                } else {
                    saveError = error?.localizedDescription ?? "Failed to save."
                }
            }
        }
    }
}

// MARK: - Share Sheet

/// UIActivityViewController wrapper for SwiftUI.
private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
