import Photos

/// Represents a photo source the user can swipe through.
enum AlbumSource: Hashable {
    case allPhotos
    case recents
    case screenshots
    case videos
    case selfies
    case livePhotos
    case favorites
    case album(PHAssetCollection)
    case duplicates

    /// Human-readable name for display in the source picker.
    var displayName: String {
        switch self {
        case .allPhotos: return "All Photos"
        case .recents: return "Last 30 Days"
        case .screenshots: return "Screenshots"
        case .videos: return "Videos"
        case .selfies: return "Selfies"
        case .livePhotos: return "Live Photos"
        case .favorites: return "Favorites"
        case .album(let collection): return collection.localizedTitle ?? "Album"
        case .duplicates: return "Duplicates"
        }
    }

    /// SF Symbol icon name for this source.
    var iconName: String {
        switch self {
        case .allPhotos: return "photo.on.rectangle.angled"
        case .recents: return "clock"
        case .screenshots: return "camera.viewfinder"
        case .videos: return "video"
        case .selfies: return "person.crop.square"
        case .livePhotos: return "livephoto"
        case .favorites: return "heart"
        case .album: return "rectangle.stack"
        case .duplicates: return "plus.square.on.square"
        }
    }

    static func == (lhs: AlbumSource, rhs: AlbumSource) -> Bool {
        switch (lhs, rhs) {
        case (.allPhotos, .allPhotos),
             (.recents, .recents),
             (.screenshots, .screenshots),
             (.videos, .videos),
             (.selfies, .selfies),
             (.livePhotos, .livePhotos),
             (.favorites, .favorites),
             (.duplicates, .duplicates):
            return true
        case (.album(let a), .album(let b)):
            return a.localIdentifier == b.localIdentifier
        default:
            return false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .allPhotos: hasher.combine("allPhotos")
        case .recents: hasher.combine("recents")
        case .screenshots: hasher.combine("screenshots")
        case .videos: hasher.combine("videos")
        case .selfies: hasher.combine("selfies")
        case .livePhotos: hasher.combine("livePhotos")
        case .favorites: hasher.combine("favorites")
        case .album(let collection): hasher.combine(collection.localIdentifier)
        case .duplicates: hasher.combine("duplicates")
        }
    }
}

/// Contains a source and its photo count, used by AlbumProvider.
struct AlbumSourceInfo: Identifiable, Hashable {
    let source: AlbumSource
    let count: Int

    var id: AlbumSource { source }

    static func == (lhs: AlbumSourceInfo, rhs: AlbumSourceInfo) -> Bool {
        lhs.source == rhs.source && lhs.count == rhs.count
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(source)
    }
}

/// Sort order for fetch results.
enum SortOrder {
    case newestFirst
    case oldestFirst
}
