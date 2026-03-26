import SwiftUI

/// Main swipe screen. Layout: progress bar, top bar, card stack, photo info, action buttons.
struct SwipeView: View {
    @StateObject private var photoLoader = PhotoLoader()
    @EnvironmentObject var deleteManager: DeleteManager
    @EnvironmentObject var sessionTracker: SessionTracker
    @EnvironmentObject var streakManager: StreakManager
    @EnvironmentObject var milestoneTracker: MilestoneTracker

    @Environment(\.dismiss) private var dismiss

    @State private var showDetail = false
    @State private var detailPhoto: PhotoItem?
    @State private var showSessionComplete = false
    @State private var showDoneConfirmation = false
    @State private var showCancelAlert = false
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?
    @State private var swipeThreshold: CGFloat = 120
    @StateObject private var swipeHistory = SwipeHistory()
    @State private var showHistoryPanel = false

    var albumName: String = "All Photos"
    var albumSource: AlbumSource = .allPhotos

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
                .environmentObject(streakManager)
                .environmentObject(milestoneTracker)
        }
        .fullScreenCover(isPresented: $showDoneConfirmation) {
            DeletionReviewView()
                .environmentObject(deleteManager)
                .environmentObject(sessionTracker)
        }
        .sheet(isPresented: $showHistoryPanel) {
            HistoryPanelView(swipeHistory: swipeHistory)
                .environmentObject(deleteManager)
        }
        .onAppear {
            if photoLoader.totalCount == 0 {
                photoLoader.loadSource(albumSource)
            }
            sessionTracker.startSession()

            let sensitivity = UserDefaults.standard.string(forKey: "settings_swipe_sensitivity") ?? "medium"
            switch sensitivity {
            case "low":
                swipeThreshold = 160
            case "high":
                swipeThreshold = 80
            default:
                swipeThreshold = 120
            }
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
            HStack(spacing: 16) {
                Button {
                    if !deleteManager.trashQueue.isEmpty {
                        showCancelAlert = true
                    } else {
                        dismiss()
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                }
                .alert("Cancel Session?", isPresented: $showCancelAlert) {
                    Button("Keep Reviewing", role: .cancel) { }
                    Button("Cancel", role: .destructive) {
                        deleteManager.clearQueue()
                        dismiss()
                    }
                } message: {
                    Text("Your \(deleteManager.trashQueue.count) selected photos won't be deleted.")
                }

                Button {
                    showHistoryPanel = true
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                }
                .opacity(swipeHistory.canUndo ? 1 : 0.4)
            }

            Spacer()

            VStack(spacing: 2) {
                Text(albumName)
                    .font(.subheadline.weight(.semibold))
                Text(photoLoader.totalCount > 0 ? "\(photoLoader.currentIndex + 1) of \(photoLoader.totalCount)" : "Loading...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Done button with trash count badge
            if !deleteManager.trashQueue.isEmpty {
                Button {
                    showDoneConfirmation = true
                } label: {
                    HStack(spacing: 4) {
                        Text("Done")
                            .font(.subheadline.weight(.semibold))
                        Text("\(deleteManager.trashQueue.count)")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(red: 255 / 255, green: 59 / 255, blue: 48 / 255))
                            .clipShape(Capsule())
                    }
                    .foregroundColor(.primary)
                }
            } else {
                Color.clear
                    .frame(width: 18, height: 18)
            }
        }
    }

    // MARK: - Card Stack Section

    private var cardStackSection: some View {
        Group {
            if photoLoader.isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text(albumSource == .smartCleanup ? "Analyzing your photos..." : "Loading photos...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if photoLoader.totalCount == 0 {
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)
                    Text("No photos found")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                CardStack(
                    swipeThreshold: swipeThreshold,
                    onShowDetail: { photo in
                        detailPhoto = photo
                        showDetail = true
                    },
                    swipeHistory: swipeHistory
                )
                .environmentObject(photoLoader)
                .environmentObject(deleteManager)
            }
        }
        .environmentObject(sessionTracker)
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
                    swipeHistory.push(action: .deleted, photoId: photo.id, photo: photo)
                    deleteManager.markForDeletion(photo)
                    sessionTracker.recordReview(kept: false, fileSize: photo.fileSize)
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

            // Center stack: undo on top, share below
            VStack(spacing: 8) {
                // Undo button (only visible when available)
                Button {
                    guard let entry = swipeHistory.undo() else { return }
                    photoLoader.goBack()
                    if entry.action == .deleted {
                        _ = deleteManager.undoLast()
                    }
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 44, height: 44)
                        .background(Color(.systemGray5))
                        .clipShape(Circle())
                }
                .opacity(swipeHistory.canUndo ? 1 : 0)
                .disabled(!swipeHistory.canUndo)
                .animation(.easeInOut(duration: 0.2), value: swipeHistory.canUndo)

                // Share button (only visible when there's a current photo)
                Button {
                    if let photo = photoLoader.currentPhoto {
                        shareImage = photo.fullImage ?? photo.thumbnail
                        showShareSheet = true
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 36, height: 36)
                        .background(Color(.systemGray5))
                        .clipShape(Circle())
                }
                .opacity(photoLoader.currentPhoto != nil ? 1 : 0)
                .disabled(photoLoader.currentPhoto == nil)
            }

            // Keep button
            Button {
                if let photo = photoLoader.currentPhoto {
                    swipeHistory.push(action: .kept, photoId: photo.id, photo: photo)
                    sessionTracker.recordReview(kept: true, fileSize: photo.fileSize)
                }
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
        .sheet(isPresented: $showShareSheet) {
            if let image = shareImage {
                ShareSheet(activityItems: [image])
            }
        }
    }
}
