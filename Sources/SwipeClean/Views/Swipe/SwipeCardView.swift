import SwiftUI

/// A single photo card with drag gesture, pinch-to-zoom, rotation, overlay indicators, and haptics.
struct SwipeCardView: View {
    let photo: PhotoItem
    let swipeThreshold: CGFloat
    let onSwiped: (SwipeDirection) -> Void
    let onDoubleTap: () -> Void
    let onLongPress: () -> Void

    @AppStorage("settings_haptic_feedback") private var hapticFeedbackEnabled: Bool = true

    @State private var offset: CGFloat = 0
    @State private var isFlyingOff = false
    @State private var flyDirection: SwipeDirection = .none
    @State private var wasPastThreshold = false
    @State private var zoomScale: CGFloat = 1.0
    @State private var lastZoomScale: CGFloat = 1.0

    private let velocityThreshold: CGFloat = 500

    var body: some View {
        GeometryReader { geometry in
            let cardWidth = geometry.size.width - 32
            let cardHeight = cardWidth * (4.0 / 3.0)

            ZStack {
                // Photo image
                photoImage
                    .frame(width: cardWidth, height: cardHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .scaleEffect(zoomScale)

                // Keep overlay (right swipe)
                if offset > 0 && zoomScale <= 1.0 {
                    keepOverlay
                        .frame(width: cardWidth, height: cardHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                // Delete overlay (left swipe)
                if offset < 0 && zoomScale <= 1.0 {
                    deleteOverlay
                        .frame(width: cardWidth, height: cardHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            .frame(width: cardWidth, height: cardHeight)
            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
            .offset(x: isFlyingOff ? SwipeGestureCalculator.flyOffOffset(direction: flyDirection) : offset)
            .rotationEffect(
                .degrees(
                    isFlyingOff
                        ? SwipeGestureCalculator.flyOffRotation(direction: flyDirection)
                        : SwipeGestureCalculator.rotation(for: offset)
                ),
                anchor: .bottom
            )
            .opacity(isFlyingOff ? 0 : 1)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(zoomScale > 1.0 ? nil : dragGesture)
            .simultaneousGesture(pinchGesture)
            .onTapGesture(count: 2) {
                if zoomScale > 1.0 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        zoomScale = 1.0
                        lastZoomScale = 1.0
                    }
                } else {
                    onDoubleTap()
                }
            }
            .onLongPressGesture(minimumDuration: 0.5) { onLongPress() }
        }
    }

    // MARK: - Photo Image

    @ViewBuilder
    private var photoImage: some View {
        if let image = photo.fullImage ?? photo.thumbnail {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Rectangle()
                .fill(Color(.systemGray5))
                .overlay {
                    ProgressView()
                }
        }
    }

    // MARK: - Overlays

    private var keepOverlay: some View {
        let opacity = SwipeGestureCalculator.overlayOpacity(for: offset, threshold: swipeThreshold)
        let scale = SwipeGestureCalculator.overlayScale(for: offset, threshold: swipeThreshold)

        return ZStack {
            Color(red: 52 / 255, green: 199 / 255, blue: 89 / 255)
                .opacity(opacity)

            VStack(spacing: 8) {
                Image(systemName: "checkmark")
                    .font(.system(size: 60, weight: .bold))
                Text("KEEP")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
            }
            .foregroundColor(.white)
            .scaleEffect(scale)
            .opacity(opacity / 0.7)
        }
    }

    private var deleteOverlay: some View {
        let opacity = SwipeGestureCalculator.overlayOpacity(for: offset, threshold: swipeThreshold)
        let scale = SwipeGestureCalculator.overlayScale(for: offset, threshold: swipeThreshold)

        return ZStack {
            Color(red: 255 / 255, green: 59 / 255, blue: 48 / 255)
                .opacity(opacity)

            VStack(spacing: 8) {
                Image(systemName: "xmark")
                    .font(.system(size: 60, weight: .bold))
                Text("DELETE")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
            }
            .foregroundColor(.white)
            .scaleEffect(scale)
            .opacity(opacity / 0.7)
        }
    }

    // MARK: - Pinch to Zoom

    private var pinchGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let newScale = lastZoomScale * value
                zoomScale = min(max(newScale, 1.0), 5.0)
            }
            .onEnded { _ in
                lastZoomScale = zoomScale
                if zoomScale <= 1.05 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        zoomScale = 1.0
                        lastZoomScale = 1.0
                    }
                }
            }
    }

    // MARK: - Drag Gesture

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                guard !isFlyingOff else { return }
                offset = value.translation.width

                let isPast = SwipeGestureCalculator.isPastThreshold(
                    offset: offset, threshold: swipeThreshold
                )
                if isPast && !wasPastThreshold {
                    lightHaptic()
                }
                wasPastThreshold = isPast
            }
            .onEnded { value in
                guard !isFlyingOff else { return }

                let velocity = value.predictedEndTranslation.width - value.translation.width
                let direction = SwipeGestureCalculator.swipeDirection(
                    offset: offset,
                    velocity: velocity,
                    threshold: swipeThreshold,
                    velocityThreshold: velocityThreshold
                )

                if direction != .none {
                    mediumHaptic()
                    flyOff(direction: direction)
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        offset = 0
                        wasPastThreshold = false
                    }
                }
            }
    }

    // MARK: - Fly Off

    private func flyOff(direction: SwipeDirection) {
        flyDirection = direction
        // Fire callback immediately so next card loads without delay
        onSwiped(direction)
        withAnimation(.easeOut(duration: 0.2)) {
            isFlyingOff = true
        }
    }

    // MARK: - Haptics

    private func lightHaptic() {
        guard hapticFeedbackEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    private func mediumHaptic() {
        guard hapticFeedbackEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}
