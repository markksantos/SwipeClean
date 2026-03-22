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

