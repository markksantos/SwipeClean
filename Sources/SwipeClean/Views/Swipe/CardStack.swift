import SwiftUI

/// Manages a visual deck of up to 3 cards.
/// Front card is interactive, back cards are scaled down and offset.
struct CardStack: View {
    @EnvironmentObject var photoLoader: PhotoLoader

    let swipeThreshold: CGFloat
    let onShowDetail: (PhotoItem) -> Void
    let coordinator: SwipeCoordinator

    var body: some View {
        ZStack {
            // Back cards first, so the interactive front card draws over them.
            ForEach(Array(backPhotos.enumerated()), id: \.element.id) { offset, photo in
                backCard(photo: photo, depth: offset + 1)
            }

            if let current = photoLoader.currentPhoto {
                SwipeCardView(
                    photo: current,
                    swipeThreshold: swipeThreshold,
                    onSwiped: { direction in
                        handleSwipe(direction: direction, photo: current)
                    },
                    onDoubleTap: { onShowDetail(current) },
                    onLongPress: { onShowDetail(current) }
                )
                .zIndex(Double(CardStackLayout.maxVisibleCards))
            }
        }
    }

    // MARK: - Back Cards

    /// The next couple of photos, drawn behind the front card so the deck reads as
    /// a physical stack and the next photo is already on screen when the front one
    /// flies away.
    private var backPhotos: [PhotoItem] {
        Array(photoLoader.upcomingPhotos.prefix(CardStackLayout.maxVisibleCards - 1))
    }

    private func backCard(photo: PhotoItem, depth: Int) -> some View {
        AssetThumbnailView(asset: photo.asset, side: 420)
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
            .padding(.horizontal, 16)
            .scaleEffect(CardStackLayout.scale(forIndex: depth))
            .offset(y: CardStackLayout.yOffset(forIndex: depth))
            .allowsHitTesting(false)
            .zIndex(Double(CardStackLayout.maxVisibleCards - depth))
    }

    // MARK: - Swipe Handling

    private func handleSwipe(direction: SwipeDirection, photo: PhotoItem) {
        switch direction {
        case .right:
            coordinator.record(.kept, photo: photo)
        case .left:
            coordinator.record(.deleted, photo: photo)
        case .none:
            break
        }
    }
}
