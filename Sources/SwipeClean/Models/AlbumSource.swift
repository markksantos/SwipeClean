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
    case onThisDay
    case random
    case month(Int, Int) // year, month (e.g. 2024, 3 for March 2024)
    case album(PHAssetCollection)
    case duplicates
    case smartCleanup
    case similarPhotos
    case autoClean

    /// Human-readable name for display in the source picker.
    var displayName: String {
        switch self {
        case .smartCleanup: return "Smart Cleanup"
        case .similarPhotos: return "Similar Photos"
        case .autoClean: return "Auto Clean"
        case .allPhotos: return "All Photos"
        case .recents: return "Last 30 Days"
        case .screenshots: return "Screenshots"
        case .videos: return "Videos"
        case .selfies: return "Selfies"
        case .livePhotos: return "Live Photos"
        case .favorites: return "Favorites"
        case .onThisDay: return "On This Day"
        case .random: return "Random"
        case .month(let year, let month):
            let df = DateFormatter()
            df.dateFormat = "MMMM yyyy"
            var comps = DateComponents()
            comps.year = year
            comps.month = month
            comps.day = 1
            if let date = Calendar.current.date(from: comps) {
                return df.string(from: date)
            }
            return "Month"
        case .album(let collection): return collection.localizedTitle ?? "Album"
        case .duplicates: return "Duplicates"
        }
    }

    /// Sort priority for display order on the home screen.
    /// Lower values appear first.
    var sortPriority: Int {
        switch self {
        case .smartCleanup: return -1
        case .allPhotos: return 0
        case .recents: return 1
        case .screenshots: return 2
        case .videos: return 3
        case .selfies: return 4
        case .livePhotos: return 5
        case .favorites: return 6
        case .onThisDay: return 7
        case .random: return 8
        case .month: return 9
        case .duplicates: return 10
        case .similarPhotos: return 11
        case .autoClean: return 12
        case .album: return 13
        }
    }

    /// SF Symbol icon name for this source.
    var iconName: String {
        switch self {
        case .smartCleanup: return "wand.and.stars"
        case .allPhotos: return "photo.on.rectangle.angled"
        case .recents: return "clock"
        case .screenshots: return "camera.viewfinder"
        case .videos: return "video"
        case .selfies: return "person.crop.square"
        case .livePhotos: return "livephoto"
        case .favorites: return "heart"
        case .onThisDay: return "calendar"
        case .random: return "shuffle"
        case .month: return "calendar.badge.clock"
        case .album: return "rectangle.stack"
        case .duplicates: return "plus.square.on.square"
        case .similarPhotos: return "square.stack.3d.down.right"
        case .autoClean: return "gearshape.2"
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
             (.onThisDay, .onThisDay),
             (.random, .random),
             (.duplicates, .duplicates),
             (.smartCleanup, .smartCleanup),
             (.similarPhotos, .similarPhotos),
             (.autoClean, .autoClean):
            return true
        case (.month(let y1, let m1), .month(let y2, let m2)):
            return y1 == y2 && m1 == m2
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
        case .onThisDay: hasher.combine("onThisDay")
        case .random: hasher.combine("random")
        case .month(let year, let month):
            hasher.combine("month")
            hasher.combine(year)
            hasher.combine(month)
        case .album(let collection): hasher.combine(collection.localIdentifier)
        case .duplicates: hasher.combine("duplicates")
        case .smartCleanup: hasher.combine("smartCleanup")
        case .similarPhotos: hasher.combine("similarPhotos")
        case .autoClean: hasher.combine("autoClean")
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
