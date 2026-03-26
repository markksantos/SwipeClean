import SwiftUI
import Photos

// MARK: - Navigation Item

struct BulkSelectNavItem: Hashable {
    let albumSource: AlbumSource
    let albumName: String
}

// MARK: - BulkSelectView

struct BulkSelectView: View {
    let albumSource: AlbumSource
    let albumName: String

    @EnvironmentObject var deleteManager: DeleteManager
    @Environment(\.dismiss) private var dismiss

    @State private var assets: [PHAsset] = []
    @State private var selectedIDs: Set<String> = []
    @State private var isLoading = true
    @State private var detailPhoto: PhotoItem?
    @State private var showDetail = false
    @State private var showReview = false
    @State private var thumbnailCache: [String: UIImage] = [:]

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    private let cachingManager = PHCachingImageManager()
    private let thumbnailSize = CGSize(width: 150, height: 150)

    var body: some View {
        ZStack {
            if isLoading {
                loadingState
            } else if assets.isEmpty {
                emptyState
            } else {
                gridContent
            }
        }
        .navigationTitle(albumName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        selectAll()
                    } label: {
                        Label("Select All", systemImage: "checkmark.circle.fill")
                    }
                    Button {
                        deselectAll()
                    } label: {
                        Label("Deselect All", systemImage: "circle")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.body.weight(.medium))
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !selectedIDs.isEmpty {
                bottomBar
            }
        }
        .fullScreenCover(isPresented: $showDetail) {
            if let photo = detailPhoto {
                PhotoDetailOverlay(photo: photo)
            }
        }
        .navigationDestination(isPresented: $showReview) {
            ReviewGridView()
                .environmentObject(deleteManager)
        }
        .task {
            await loadAssets()
        }
    }

    // MARK: - Subviews

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading photos...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("No photos found")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    private var gridContent: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(assets, id: \.localIdentifier) { asset in
                    BulkSelectCell(
                        asset: asset,
                        isSelected: selectedIDs.contains(asset.localIdentifier),
                        thumbnailSize: thumbnailSize,
                        cachingManager: cachingManager,
                        onTap: {
                            toggleSelection(asset)
                        },
                        onLongPress: {
                            showFullScreen(asset)
                        }
                    )
                }
            }
            // Extra padding at bottom so content isn't hidden behind the bottom bar
            .padding(.bottom, 80)
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(selectedIDs.count) selected")
                        .font(.headline)
                    Text(selectedSizeText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    addSelectedToTrash()
                } label: {
                    Label("Delete Selected", systemImage: "trash")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.red, in: Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(.ultraThinMaterial)
    }

    // MARK: - Computed

    private var selectedSizeText: String {
        let totalBytes = selectedAssets.reduce(Int64(0)) { total, asset in
            let resources = PHAssetResource.assetResources(for: asset)
            let size: Int64 = resources.reduce(0) { $0 + (($1.value(forKey: "fileSize") as? Int64) ?? 0) }
            return total + size
        }
        return SwipeFormatters.fileSize(bytes: totalBytes)
    }

    private var selectedAssets: [PHAsset] {
        assets.filter { selectedIDs.contains($0.localIdentifier) }
    }

    // MARK: - Actions

    private func selectAll() {
        selectedIDs = Set(assets.map(\.localIdentifier))
    }

    private func deselectAll() {
        selectedIDs.removeAll()
    }

    private func toggleSelection(_ asset: PHAsset) {
        if selectedIDs.contains(asset.localIdentifier) {
            selectedIDs.remove(asset.localIdentifier)
        } else {
            selectedIDs.insert(asset.localIdentifier)
        }
    }

    private func showFullScreen(_ asset: PHAsset) {
        let item = PhotoItem(asset: asset)
        // Load full image for detail view
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true

        PHImageManager.default().requestImage(
            for: asset,
            targetSize: PHImageManagerMaximumSize,
            contentMode: .aspectFit,
            options: options
        ) { image, _ in
            DispatchQueue.main.async {
                item.fullImage = image
                self.detailPhoto = item
                self.showDetail = true
            }
        }
    }

    private func addSelectedToTrash() {
        let assetsToDelete = selectedAssets
        for asset in assetsToDelete {
            let item = PhotoItem(asset: asset)
            deleteManager.queueForDeletion(item)
        }

        selectedIDs.removeAll()
        showReview = true
    }

    // MARK: - Data Loading

    private func loadAssets() async {
        let fetcher = LiveAssetFetcher()
        let fetched = await Task.detached {
            fetcher.fetchAssets(for: albumSource, sortOrder: .newestFirst)
        }.value

        // Start caching thumbnails
        cachingManager.startCachingImages(
            for: fetched,
            targetSize: thumbnailSize,
            contentMode: .aspectFill,
            options: nil
        )

        await MainActor.run {
            assets = fetched
            isLoading = false
        }
    }
}

// MARK: - BulkSelectCell

private struct BulkSelectCell: View {
    let asset: PHAsset
    let isSelected: Bool
    let thumbnailSize: CGSize
    let cachingManager: PHCachingImageManager
    let onTap: () -> Void
    let onLongPress: () -> Void

    @State private var thumbnail: UIImage?

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topTrailing) {
                // Thumbnail
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.width)
                        .clipped()
                } else {
                    Color(.secondarySystemFill)
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.6)
                        )
                }

                // Selection overlay
                if isSelected {
                    Color.blue.opacity(0.25)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .shadow(radius: 2)
                        .padding(6)
                }

                // Video duration badge
                if asset.mediaType == .video {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text(SwipeFormatters.duration(seconds: asset.duration))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.black.opacity(0.6), in: Capsule())
                                .padding(4)
                        }
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.width)
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()
            }
            .onLongPressGesture {
                onLongPress()
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .task {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = false
        options.resizeMode = .fast

        let image = await withCheckedContinuation { (continuation: CheckedContinuation<UIImage?, Never>) in
            cachingManager.requestImage(
                for: asset,
                targetSize: thumbnailSize,
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                // Only resume on the final delivery (not the degraded one)
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if !isDegraded {
                    continuation.resume(returning: image)
                }
            }
        }

        await MainActor.run {
            self.thumbnail = image
        }
    }
}
