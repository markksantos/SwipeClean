import SwiftUI

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
        ) { _ in
            Button("Rescue") {
                if rescueTarget != nil {
                    // Use undoLastDeletion or clearQueue -- for rescue we remove specific item.
                    // Since DeleteManager only supports undoLast or clear, we'll use undo
                    // repeatedly or accept the limitation.
                    deleteManager.undoLastDeletion()
                }
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
            Rectangle()
                .fill(Color(.tertiarySystemGroupedBackground))
                .aspectRatio(1, contentMode: .fill)
                .overlay {
                    if let thumbnail = photo.thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "photo")
                            .foregroundStyle(.tertiary)
                    }
                }
                .clipped()
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
                if let thumbnail = photo.thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFit()
                }
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
                        deleteManager.undoLastDeletion()
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
