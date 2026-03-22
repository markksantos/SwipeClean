import SwiftUI

/// Main swipe screen. Layout: progress bar, top bar, card stack, photo info, action buttons.
struct SwipeView: View {
    @EnvironmentObject var photoLoader: PhotoLoader
    @EnvironmentObject var deleteManager: DeleteManager
    @EnvironmentObject var sessionTracker: SessionTracker

    @Environment(\.dismiss) private var dismiss

    @State private var showDetail = false
    @State private var detailPhoto: PhotoItem?
    @State private var showSessionComplete = false
    @State private var swipeThreshold: CGFloat = 120

    var albumName: String = "All Photos"

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress bar
                progressBar

                // Top bar
                topBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                Spacer(minLength: 16)

                // Card stack
                cardStackSection

                // Photo info
                photoInfoBar
                    .padding(.top, 8)

                Spacer(minLength: 16)

                // Action buttons
                actionButtons
                    .padding(.bottom, 24)
            }
        }
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $showDetail) {
            if let photo = detailPhoto {
                PhotoDetailOverlay(photo: photo)
            }
        }
        .fullScreenCover(isPresented: $showSessionComplete) {
            SessionCompleteView()
                .environmentObject(deleteManager)
                .environmentObject(sessionTracker)
        }
        .onChange(of: photoLoader.currentPhoto == nil) { isNil in
            if isNil && photoLoader.currentIndex >= photoLoader.totalCount && photoLoader.totalCount > 0 {
                showSessionComplete = true
            }
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(Color.accentColor)
                .frame(
                    width: geometry.size.width * CGFloat(photoLoader.progress),
                    height: 3
                )
                .animation(.easeInOut(duration: 0.3), value: photoLoader.progress)
        }
        .frame(height: 3)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
            }

            Spacer()

            VStack(spacing: 2) {
                Text(albumName)
                    .font(.subheadline.weight(.semibold))
                Text("\(photoLoader.currentIndex + 1) of \(photoLoader.totalCount)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Spacer to balance the close button
            Color.clear
                .frame(width: 18, height: 18)
        }
    }

    // MARK: - Card Stack Section

    private var cardStackSection: some View {
        CardStack(
            swipeThreshold: swipeThreshold,
            onShowDetail: { photo in
                detailPhoto = photo
                showDetail = true
            }
        )
        .environmentObject(photoLoader)
        .environmentObject(deleteManager)
    }

    // MARK: - Photo Info

    private var photoInfoBar: some View {
        Group {
            if let photo = photoLoader.currentPhoto {
                HStack(spacing: 12) {
                    if let date = photo.creationDate {
                        Text(SwipeFormatters.photoDate(date))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if photo.fileSize > 0 {
                        Text(SwipeFormatters.fileSize(bytes: photo.fileSize))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if let duration = photo.duration, duration > 0 {
                        Text(SwipeFormatters.duration(seconds: duration))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 32) {
            // Delete button
            Button {
                if let photo = photoLoader.currentPhoto {
                    deleteManager.markForDeletion(photo)
                    photoLoader.advance()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 64, height: 64)
                    .background(Color(red: 255 / 255, green: 59 / 255, blue: 48 / 255))
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
            }

            // Undo button (only visible when available)
            Button {
                // Undo handled through CardStack — need shared state
                _ = deleteManager.undoLast()
                photoLoader.goBack()
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 44, height: 44)
                    .background(Color(.systemGray5))
                    .clipShape(Circle())
            }
            .opacity(deleteManager.canUndo ? 1 : 0)
            .disabled(!deleteManager.canUndo)
            .animation(.easeInOut(duration: 0.2), value: deleteManager.canUndo)

            // Keep button
            Button {
                photoLoader.advance()
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 64, height: 64)
                    .background(Color(red: 52 / 255, green: 199 / 255, blue: 89 / 255))
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
            }
        }
    }
}
