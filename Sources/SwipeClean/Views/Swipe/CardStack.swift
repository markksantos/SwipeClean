import SwiftUI

/// Manages a visual deck of up to 3 cards.
/// Front card is interactive, back cards are scaled down and offset.
struct CardStack: View {
    @EnvironmentObject var photoLoader: PhotoLoader
    @EnvironmentObject var deleteManager: DeleteManager
    @EnvironmentObject var sessionTracker: SessionTracker

    let swipeThreshold: CGFloat
    let onShowDetail: (PhotoItem) -> Void

    @ObservedObject var swipeHistory: SwipeHistory

    var body: some View {
        let visiblePhotos = buildVisiblePhotos()

        ZStack {
            ForEach(Array(visiblePhotos.enumerated().reversed()), id: \.element.id) { index, photo in
                let stackIndex = index

                if stackIndex == 0 {
                    // Front card: interactive
                    SwipeCardView(
                        photo: photo,
                        swipeThreshold: swipeThreshold,
                        onSwiped: { direction in
                            handleSwipe(direction: direction, photo: photo)
                        },
                        onDoubleTap: { onShowDetail(photo) },
                        onLongPress: { onShowDetail(photo) }
                    )
                    .zIndex(Double(CardStackLayout.maxVisibleCards - stackIndex))
                }
                // Back cards hidden — only preload them for smooth transitions
            }
        }
    }

    // MARK: - Back Card

    @ViewBuilder
    private func backCard(photo: PhotoItem, stackIndex: Int) -> some View {
        GeometryReader { geometry in
            let cardWidth = geometry.size.width - 32
            let cardHeight = cardWidth * (4.0 / 3.0)

            Group {
                if let image = photo.thumbnail ?? photo.fullImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: cardWidth, height: cardHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemGray5))
                        .frame(width: cardWidth, height: cardHeight)
                }
            }
            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
            .scaleEffect(CardStackLayout.scale(forIndex: stackIndex))
            .offset(y: CardStackLayout.yOffset(forIndex: stackIndex))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: photoLoader.currentIndex)
        }
    }

    // MARK: - Visible Photos

    private func buildVisiblePhotos() -> [PhotoItem] {
        var photos: [PhotoItem] = []
        if let current = photoLoader.currentPhoto {
            photos.append(current)
        }
        let upcoming = Array(photoLoader.upcomingPhotos.prefix(CardStackLayout.maxVisibleCards - 1))
        photos.append(contentsOf: upcoming)
        return photos
    }

    // MARK: - Swipe Handling

    private func handleSwipe(direction: SwipeDirection, photo: PhotoItem) {
        switch direction {
        case .right:
            // Keep: just advance
            swipeHistory.push(action: .kept, photoId: photo.id, photo: photo)
            sessionTracker.recordReview(kept: true, fileSize: photo.fileSize)
            photoLoader.advance()
        case .left:
            // Delete: mark for deletion, then advance
            swipeHistory.push(action: .deleted, photoId: photo.id, photo: photo)
            deleteManager.markForDeletion(photo)
            sessionTracker.recordReview(kept: false, fileSize: photo.fileSize)
            photoLoader.advance()
        case .none:
            break
        }
    }

    // MARK: - Undo

    func performUndo() {
        guard let entry = swipeHistory.undo() else { return }
        photoLoader.goBack()
        if entry.action == .deleted {
            _ = deleteManager.undoLast()
        }
    }

    var canUndo: Bool {
        swipeHistory.canUndo
    }
}
