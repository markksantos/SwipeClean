import SwiftUI
import Photos

/// Session completion screen with stats, delete action, and confetti.
struct SessionCompleteView: View {
    @EnvironmentObject var deleteManager: DeleteManager
    @EnvironmentObject var sessionTracker: SessionTracker

    @Environment(\.dismiss) private var dismiss

    @State private var showReviewGrid = false
    @State private var isDeleting = false
    @State private var deleteComplete = false
    @State private var animateStats = false
    @State private var confettiParticles: [ConfettiParticle] = []
    @State private var showConfetti = false

    private var shouldShowConfetti: Bool {
        SessionCompleteLogic.shouldShowConfetti(storageFreed: deleteManager.storageFreed)
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        Spacer(minLength: 40)

                        // Cleaned count
                        cleanedHeader

                        // Stats row
                        statsRow

                        // Storage freed
                        storageFreedDisplay

                        Spacer(minLength: 24)

                        // Action buttons
                        actionButtons
                    }
                    .padding(.horizontal, 24)
                }

                // Confetti overlay
                if showConfetti {
                    confettiOverlay
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showReviewGrid) {
                ReviewGridView(photos: deleteManager.trashQueue)
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                    animateStats = true
                }
                if shouldShowConfetti {
                    startConfetti()
                }
            }
        }
    }

    // MARK: - Cleaned Header

    private var cleanedHeader: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text("\(deleteManager.photosDeleted)")
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .scaleEffect(animateStats ? 1.0 : 0.5)
                .opacity(animateStats ? 1.0 : 0.0)

            Text("photos cleaned")
                .font(.title3.weight(.medium))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 4) {
            Text("Reviewed: \(deleteManager.photosReviewed)")
            Text("·")
            Text("Kept: \(deleteManager.photosKept)")
            Text("·")
            Text("Deleted: \(deleteManager.photosDeleted)")
        }
        .font(.subheadline)
        .foregroundColor(.secondary)
        .opacity(animateStats ? 1.0 : 0.0)
    }

    // MARK: - Storage Freed

    private var storageFreedDisplay: some View {
        VStack(spacing: 4) {
            Text(SwipeFormatters.fileSize(bytes: deleteManager.storageFreed))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .scaleEffect(animateStats ? 1.0 : 0.5)
                .opacity(animateStats ? 1.0 : 0.0)

            Text("freed")
                .font(.title3.weight(.medium))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Delete Now
            Button {
                Task {
                    isDeleting = true
                    await deleteManager.executeDelete()
                    isDeleting = false
                    deleteComplete = true
                }
            } label: {
                HStack {
                    if isDeleting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "trash.fill")
                        Text(deleteComplete ? "Deleted" : "Delete Now")
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(deleteComplete ? Color.gray : Color(red: 255 / 255, green: 59 / 255, blue: 48 / 255))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(isDeleting || deleteComplete)

            // Review Before Deleting
            Button {
                showReviewGrid = true
            } label: {
                Text("Review Before Deleting")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(isDeleting || deleteComplete)
        }
    }

    // MARK: - Confetti

    private func startConfetti() {
        confettiParticles = (0..<25).map { _ in
            ConfettiParticle(
                x: CGFloat.random(in: 0...1),
                delay: Double.random(in: 0...0.5),
                color: [Color.red, .blue, .green, .yellow, .orange, .purple, .pink].randomElement()!,
                size: CGFloat.random(in: 6...12)
            )
        }
        showConfetti = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            showConfetti = false
        }
    }

    private var confettiOverlay: some View {
        Canvas { context, size in
            let elapsed = Date().timeIntervalSinceReferenceDate

            for particle in confettiParticles {
                let x = particle.x * size.width
                let progress = min(1.0, max(0, (elapsed.truncatingRemainder(dividingBy: 3.0) - particle.delay) / 2.0))
                let y = progress * size.height * 1.2 - 20

                if progress > 0 {
                    let rect = CGRect(
                        x: x + sin(progress * .pi * 3) * 20,
                        y: y,
                        width: particle.size,
                        height: particle.size
                    )
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(particle.color.opacity(1.0 - progress))
                    )
                }
            }
        }
        .onAppear {
            // Force re-render via timer for animation
            Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { timer in
                if !showConfetti {
                    timer.invalidate()
                }
            }
        }
    }
}

// MARK: - Confetti Particle

struct ConfettiParticle: Identifiable {
    let id = UUID()
    let x: CGFloat
    let delay: Double
    let color: Color
    let size: CGFloat
}

// MARK: - Review Grid View

/// Grid of photos queued for deletion, allowing review before final delete.
struct ReviewGridView: View {
    let photos: [PhotoItem]

    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 150), spacing: 2)
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(photos, id: \.id) { photo in
                        if let image = photo.thumbnail ?? photo.fullImage {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(1, contentMode: .fill)
                                .clipped()
                        } else {
                            Rectangle()
                                .fill(Color(.systemGray5))
                                .aspectRatio(1, contentMode: .fill)
                        }
                    }
                }
            }
            .navigationTitle("Queued for Deletion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
