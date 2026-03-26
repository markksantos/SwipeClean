import SwiftUI
import Photos

// MARK: - View Model

@MainActor
final class StorageBreakdownViewModel: ObservableObject {

    struct Category: Identifiable {
        let id = UUID()
        let name: String
        let icon: String
        let color: Color
        let bytes: Int64
        let count: Int
    }

    @Published var categories: [Category] = []
    @Published var totalBytes: Int64 = 0
    @Published var isLoading = true

    func load() {
        isLoading = true
        Task.detached {
            let result = Self.computeCategories()
            let sorted = result.sorted { $0.bytes > $1.bytes }
            let total = result.reduce(Int64(0)) { $0 + $1.bytes }
            await MainActor.run { [weak self] in
                self?.categories = sorted
                self?.totalBytes = total
                self?.isLoading = false
            }
        }
    }

    // MARK: - Background computation

    nonisolated private static func computeCategories() -> [Category] {
        // Fetch asset identifiers for each smart album category
        let screenshotIDs = assetIDs(forSmartAlbum: .smartAlbumScreenshots)
        let selfieIDs = assetIDs(forSmartAlbum: .smartAlbumSelfPortraits)
        let livePhotoIDs = assetIDs(forSmartAlbum: .smartAlbumLivePhotos)

        // Fetch all assets and classify
        let allAssets = PHAsset.fetchAssets(with: nil)
        var photosBytes: Int64 = 0; var photosCount = 0
        var videosBytes: Int64 = 0; var videosCount = 0
        var screenshotsBytes: Int64 = 0; var screenshotsCount = 0
        var selfiesBytes: Int64 = 0; var selfiesCount = 0
        var livePhotosBytes: Int64 = 0; var livePhotosCount = 0
        var otherBytes: Int64 = 0; var otherCount = 0

        allAssets.enumerateObjects { asset, _, _ in
            let size = Self.estimatedSize(for: asset)
            let identifier = asset.localIdentifier

            if asset.mediaType == .video {
                videosBytes += size
                videosCount += 1
            } else if screenshotIDs.contains(identifier) {
                screenshotsBytes += size
                screenshotsCount += 1
            } else if selfieIDs.contains(identifier) {
                selfiesBytes += size
                selfiesCount += 1
            } else if livePhotoIDs.contains(identifier) {
                livePhotosBytes += size
                livePhotosCount += 1
            } else if asset.mediaType == .image {
                photosBytes += size
                photosCount += 1
            } else {
                otherBytes += size
                otherCount += 1
            }
        }

        var results: [Category] = []

        if photosCount > 0 {
            results.append(Category(name: "Photos", icon: "photo", color: .blue, bytes: photosBytes, count: photosCount))
        }
        if videosCount > 0 {
            results.append(Category(name: "Videos", icon: "video", color: .purple, bytes: videosBytes, count: videosCount))
        }
        if screenshotsCount > 0 {
            results.append(Category(name: "Screenshots", icon: "camera.viewfinder", color: .green, bytes: screenshotsBytes, count: screenshotsCount))
        }
        if selfiesCount > 0 {
            results.append(Category(name: "Selfies", icon: "person.crop.square", color: .orange, bytes: selfiesBytes, count: selfiesCount))
        }
        if livePhotosCount > 0 {
            results.append(Category(name: "Live Photos", icon: "livephoto", color: .cyan, bytes: livePhotosBytes, count: livePhotosCount))
        }
        if otherCount > 0 {
            results.append(Category(name: "Other", icon: "ellipsis.circle", color: .gray, bytes: otherBytes, count: otherCount))
        }

        return results
    }

    nonisolated private static func assetIDs(forSmartAlbum subtype: PHAssetCollectionSubtype) -> Set<String> {
        let collections = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: subtype, options: nil)
        guard let collection = collections.firstObject else { return [] }
        let assets = PHAsset.fetchAssets(in: collection, options: nil)
        var ids = Set<String>()
        assets.enumerateObjects { asset, _, _ in
            ids.insert(asset.localIdentifier)
        }
        return ids
    }

    nonisolated private static func estimatedSize(for asset: PHAsset) -> Int64 {
        let resources = PHAssetResource.assetResources(for: asset)
        var total: Int64 = 0
        for resource in resources {
            if let size = resource.value(forKey: "fileSize") as? Int64 {
                total += size
            }
        }
        // Fallback estimate if no file size available
        if total == 0 {
            if asset.mediaType == .video {
                total = Int64(asset.duration * 2_000_000) // ~2 MB/s rough estimate
            } else {
                total = 3_500_000 // ~3.5 MB average photo
            }
        }
        return total
    }
}

// MARK: - View

struct StorageBreakdownView: View {

    @StateObject private var viewModel = StorageBreakdownViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if viewModel.isLoading {
                    loadingView
                } else {
                    totalHeader
                    ringChart
                    categoryList
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .navigationTitle("Storage")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            viewModel.load()
        }
    }

    // MARK: - Subviews

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Analyzing your library...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    private var totalHeader: some View {
        VStack(spacing: 4) {
            Text(StorageFormatter.humanReadable(bytes: viewModel.totalBytes))
                .font(.system(size: 42, weight: .bold, design: .rounded))
            Text("Total Library Size")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var ringChart: some View {
        ZStack {
            ForEach(Array(viewModel.categories.enumerated()), id: \.element.id) { index, category in
                let startAngle = startAngle(for: index)
                let endAngle = endAngle(for: index)
                Circle()
                    .trim(from: startAngle, to: endAngle)
                    .stroke(category.color, style: StrokeStyle(lineWidth: 22, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
            }
        }
        .frame(height: 180)
        .padding(.horizontal, 40)
        .padding(.vertical, 8)
    }

    private func startAngle(for index: Int) -> CGFloat {
        guard viewModel.totalBytes > 0 else { return 0 }
        var angle: CGFloat = 0
        for i in 0..<index {
            angle += CGFloat(viewModel.categories[i].bytes) / CGFloat(viewModel.totalBytes)
        }
        return angle
    }

    private func endAngle(for index: Int) -> CGFloat {
        guard viewModel.totalBytes > 0 else { return 0 }
        let start = startAngle(for: index)
        let segment = CGFloat(viewModel.categories[index].bytes) / CGFloat(viewModel.totalBytes)
        // Small gap between segments
        return start + max(segment - 0.005, 0)
    }

    private var categoryList: some View {
        VStack(spacing: 10) {
            ForEach(viewModel.categories) { category in
                categoryRow(category)
            }
        }
    }

    private func categoryRow(_ category: StorageBreakdownViewModel.Category) -> some View {
        let percentage = viewModel.totalBytes > 0
            ? Double(category.bytes) / Double(viewModel.totalBytes) * 100
            : 0

        return HStack(spacing: 12) {
            Image(systemName: category.icon)
                .font(.title3)
                .foregroundStyle(category.color)
                .frame(width: 36, height: 36)
                .background(category.color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(category.name)
                        .font(.body.weight(.medium))
                    Spacer()
                    Text(StorageFormatter.humanReadable(bytes: category.bytes))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                }

                HStack(spacing: 8) {
                    // Horizontal bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(Color.secondary.opacity(0.12))
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(category.color)
                                .frame(width: geo.size.width * CGFloat(percentage / 100))
                        }
                    }
                    .frame(height: 6)

                    Text(String(format: "%.1f%%", percentage))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 46, alignment: .trailing)
                }

                Text("\(category.count) items")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        StorageBreakdownView()
    }
}
