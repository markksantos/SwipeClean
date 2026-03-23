import SwiftUI
import Photos

struct AlbumCard: View {
    let source: AlbumSource
    let photoCount: Int
    let onTap: () -> Void

    @State private var thumbnail: UIImage?

    private var isEmpty: Bool {
        photoCount == 0
    }

    /// Whether this card's source type supports supercut creation and should show a film badge.
    private var showsFilmBadge: Bool {
        switch source {
        case .month, .onThisDay, .recents:
            return !isEmpty
        default:
            return false
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Icon
                Image(systemName: source.iconName)
                    .font(.title2)
                    .foregroundStyle(isEmpty ? .tertiary : .primary)
                    .frame(width: 40, height: 40)
                    .background(isEmpty ? Color.secondary.opacity(0.08) : Color.accentColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(alignment: .bottomTrailing) {
                        if showsFilmBadge {
                            Image(systemName: "film")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(3)
                                .background(Color.accentColor, in: Circle())
                                .offset(x: 4, y: 4)
                        }
                    }

                // Name and count
                VStack(alignment: .leading, spacing: 2) {
                    Text(source.displayName)
                        .font(.body.weight(.medium))
                        .foregroundStyle(isEmpty ? .tertiary : .primary)
                        .lineLimit(1)

                    if isEmpty {
                        Text("Empty")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    } else {
                        Text("\(photoCount) photos")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Preview thumbnail
                if !isEmpty {
                    if let thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.secondary.opacity(0.12))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            )
                    }
                }

                if !isEmpty {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(PressDownButtonStyle())
        .disabled(isEmpty)
        .task {
            guard !isEmpty else { return }
            thumbnail = await loadThumbnail(for: source)
        }
    }

    /// Loads a small thumbnail (80x80) for the first asset of the album source.
    private func loadThumbnail(for source: AlbumSource) async -> UIImage? {
        let fetchResult: PHFetchResult<PHAsset>

        switch source {
        case .allPhotos:
            let options = PHFetchOptions()
            options.fetchLimit = 1
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            fetchResult = PHAsset.fetchAssets(with: options)
        case .recents:
            let options = PHFetchOptions()
            options.fetchLimit = 1
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            options.predicate = NSPredicate(format: "creationDate >= %@", thirtyDaysAgo as NSDate)
            fetchResult = PHAsset.fetchAssets(with: options)
        case .screenshots:
            let options = PHFetchOptions()
            options.fetchLimit = 1
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            options.predicate = NSPredicate(format: "mediaSubtype == %d", PHAssetMediaSubtype.photoScreenshot.rawValue)
            fetchResult = PHAsset.fetchAssets(with: options)
        case .videos:
            let options = PHFetchOptions()
            options.fetchLimit = 1
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            fetchResult = PHAsset.fetchAssets(with: .video, options: options)
        case .selfies:
            let collections = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumSelfPortraits, options: nil)
            guard let collection = collections.firstObject else { return nil }
            let options = PHFetchOptions()
            options.fetchLimit = 1
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            fetchResult = PHAsset.fetchAssets(in: collection, options: options)
        case .livePhotos:
            let options = PHFetchOptions()
            options.fetchLimit = 1
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            options.predicate = NSPredicate(format: "mediaSubtype == %d", PHAssetMediaSubtype.photoLive.rawValue)
            fetchResult = PHAsset.fetchAssets(with: options)
        case .favorites:
            let collections = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumFavorites, options: nil)
            guard let collection = collections.firstObject else { return nil }
            let options = PHFetchOptions()
            options.fetchLimit = 1
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            fetchResult = PHAsset.fetchAssets(in: collection, options: options)
        case .album(let collection):
            let options = PHFetchOptions()
            options.fetchLimit = 1
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            fetchResult = PHAsset.fetchAssets(in: collection, options: options)
        case .onThisDay, .random, .duplicates:
            let options = PHFetchOptions()
            options.fetchLimit = 1
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            fetchResult = PHAsset.fetchAssets(with: options)
        case .month(let year, let month):
            let calendar = Calendar.current
            var startComps = DateComponents()
            startComps.year = year
            startComps.month = month
            startComps.day = 1
            guard let start = calendar.date(from: startComps),
                  let end = calendar.date(byAdding: .month, value: 1, to: start) else { return nil }
            let options = PHFetchOptions()
            options.fetchLimit = 1
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            options.predicate = NSPredicate(format: "creationDate >= %@ AND creationDate < %@", start as NSDate, end as NSDate)
            fetchResult = PHAsset.fetchAssets(with: options)
        }

        guard let asset = fetchResult.firstObject else { return nil }

        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .fastFormat
            options.isNetworkAccessAllowed = false
            options.resizeMode = .fast

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 80, height: 80),
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
}

// MARK: - Press-Down Button Style

struct PressDownButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    VStack(spacing: 12) {
        AlbumCard(source: .allPhotos, photoCount: 1234) {}
        AlbumCard(source: .screenshots, photoCount: 56) {}
        AlbumCard(source: .videos, photoCount: 0) {}
    }
    .padding()
}
