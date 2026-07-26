import SwiftUI
import Photos

struct AlbumCard: View {
    let source: AlbumSource
    let photoCount: Int
    /// Draws a lock instead of the chevron. The card still taps through — it opens
    /// the paywall rather than the feature, so the row never looks broken.
    var isLocked: Bool = false
    let onTap: () -> Void

    /// Injected so previews and tests are not forced to touch a real library.
    var assetFetcher: AssetFetching = LiveAssetFetcher()

    @State private var previewAsset: PHAsset?

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

                    if photoCount == -1 {
                        Text("AI-powered")
                            .font(.caption)
                            .foregroundStyle(.purple)
                    } else if isEmpty {
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
                    AssetThumbnailView(asset: previewAsset, side: 44)
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tint)
                        .accessibilityLabel("Requires SwipeClean Pro")
                } else if !isEmpty {
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
        // A locked row must stay tappable even with nothing to show yet, because
        // its tap opens the paywall rather than the album.
        .disabled(isEmpty && !isLocked)
        .task(id: source) {
            guard !isEmpty, previewAsset == nil else { return }
            // Off the main thread: a PhotoKit fetch against a large library is
            // not instant, and this runs once per visible card.
            let source = source
            previewAsset = await Task.detached { assetFetcher.representativeAsset(for: source) }.value
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
