import Foundation

/// Groups album sources into smart albums and user albums for display.
enum AlbumSourceGrouper {
    struct GroupedSources {
        let smart: [AlbumSource]
        let user: [AlbumSource]
    }

    static func group(_ sources: [AlbumSource]) -> GroupedSources {
        var smart: [AlbumSource] = []
        var user: [AlbumSource] = []

        for source in sources {
            switch source {
            case .album:
                user.append(source)
            default:
                smart.append(source)
            }
        }

        return GroupedSources(smart: smart, user: user)
    }
}

// MARK: - Hashable Conformance for AlbumSource

extension AlbumSource: Hashable {
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
