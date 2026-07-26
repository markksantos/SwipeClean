import SwiftUI
import Photos

struct ReviewGridView: View {
    @EnvironmentObject private var deleteManager: DeleteManager
    @State private var selectedPhoto: PhotoItem?
    @State private var rescueTarget: PhotoItem?
    @State private var showRescueConfirmation = false

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        Group {
            if deleteManager.trashQueue.isEmpty {
                emptyState
            } else {
                gridContent
            }
        }
        .navigationTitle("Queued for Deletion")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Rescue this photo?",
            isPresented: $showRescueConfirmation,
            presenting: rescueTarget
        ) { photo in
            Button("Rescue") {
                // Must target the photo the user long-pressed. Calling
                // `undoLastDeletion()` here rescued whatever was queued most
                // recently instead, so the tapped photo stayed queued and an
                // unrelated one was silently spared.
                deleteManager.removeFromTrash(photoId: photo.id)
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("This will remove the photo from the deletion queue.")
        }
        .fullScreenCover(item: $selectedPhoto) { photo in
            fullScreenPhotoView(photo)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "trash.slash")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("No photos queued")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Swipe left on photos to add them here")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var gridContent: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(deleteManager.trashQueue, id: \.id) { photo in
                    gridCell(for: photo)
                }
            }
        }
    }

    private func gridCell(for photo: PhotoItem) -> some View {
        Button {
            selectedPhoto = photo
        } label: {
            AssetThumbnailView(asset: photo.asset)
                .aspectRatio(1, contentMode: .fill)
        }
        .buttonStyle(.plain)
        .onLongPressGesture {
            rescueTarget = photo
            showRescueConfirmation = true
        }
    }

    private func fullScreenPhotoView(_ photo: PhotoItem) -> some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                AssetThumbnailView(asset: photo.asset, side: 1_000, fills: false)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        selectedPhoto = nil
                    }
                    .foregroundStyle(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        deleteManager.removeFromTrash(photoId: photo.id)
                        selectedPhoto = nil
                    } label: {
                        Label("Rescue", systemImage: "arrow.uturn.backward")
                            .foregroundStyle(.white)
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ReviewGridView()
    }
}
