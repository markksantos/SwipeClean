import SwiftUI
import Photos

/// Session completion screen with stats, delete action, and confetti.
struct SessionCompleteView: View {
    @EnvironmentObject var deleteManager: DeleteManager
    @EnvironmentObject var sessionTracker: SessionTracker
    @EnvironmentObject var streakManager: StreakManager
    @EnvironmentObject var milestoneTracker: MilestoneTracker

    @Environment(\.dismiss) private var dismiss

    @State private var showReviewGrid = false
    @State private var isDeleting = false
    @State private var deleteComplete = false
    @State private var deleteError: String?
    @State private var animateStats = false
    @State private var confettiParticles: [ConfettiParticle] = []
    @State private var showConfetti = false
    @State private var confettiStart = Date()
    @State private var earnedMilestones: [Milestone] = []
    @State private var showMilestoneCelebration = false

    private var shouldShowConfetti: Bool {
        SessionCompleteLogic.shouldShowConfetti(storageFreed: sessionTracker.sessionStats.storageFreed)
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

                        // Milestone celebration
                        if showMilestoneCelebration && !earnedMilestones.isEmpty {
                            milestoneCelebrationBanner
                        }

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
                DeletionPreviewGrid(photos: deleteManager.trashQueue)
            }
            .onAppear {
                sessionTracker.endSession()
                streakManager.recordSession()

                // Check for new milestones
                let stats = sessionTracker.lifetimeStats
                earnedMilestones = milestoneTracker.checkAndAward(
                    photosReviewed: stats.totalPhotosReviewed,
                    storageFreed: stats.totalStorageFreed,
                    currentStreak: streakManager.currentStreak
                )

                withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                    animateStats = true
                }
                if !earnedMilestones.isEmpty {
                    withAnimation(.easeOut(duration: 0.5).delay(0.8)) {
                        showMilestoneCelebration = true
                    }
                    // Also trigger confetti for milestone celebration
                    if !shouldShowConfetti {
                        startConfetti()
                    }
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

            Text("\(sessionTracker.sessionStats.photosDeleted)")
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
            Text("Reviewed: \(sessionTracker.sessionStats.photosReviewed)")
            Text("·")
            Text("Kept: \(sessionTracker.sessionStats.photosKept)")
            Text("·")
            Text("Deleted: \(sessionTracker.sessionStats.photosDeleted)")
        }
        .font(.subheadline)
        .foregroundColor(.secondary)
        .opacity(animateStats ? 1.0 : 0.0)
    }

    // MARK: - Storage Freed

    private var storageFreedDisplay: some View {
        VStack(spacing: 4) {
            Text(SwipeFormatters.fileSize(bytes: sessionTracker.sessionStats.storageFreed))
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
                isDeleting = true
                deleteError = nil
                deleteManager.executeQueuedDeletions { result in
                    isDeleting = false
                    // The result has to be honoured. iOS shows its own
                    // confirmation for a batch delete, and declining it comes back
                    // as a failure — this button used to latch to "Deleted" and
                    // disable itself anyway, telling the user their photos were
                    // gone when nothing had been touched.
                    switch result {
                    case .success:
                        deleteComplete = true
                    case .failure(let error):
                        deleteError = error.localizedDescription
                    }
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

            if let deleteError {
                Text(deleteError)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }

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

    // MARK: - Milestone Celebration

    private var milestoneCelebrationBanner: some View {
        VStack(spacing: 12) {
            ForEach(earnedMilestones) { milestone in
                HStack(spacing: 12) {
                    Image(systemName: milestone.icon)
                        .font(.title2)
                        .foregroundStyle(.yellow)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Milestone Earned!")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(milestone.title)
                            .font(.headline)
                    }

                    Spacer()
                }
                .padding(16)
                .background(
                    LinearGradient(
                        colors: [Color.yellow.opacity(0.12), Color.orange.opacity(0.08)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.yellow.opacity(0.2), lineWidth: 1)
                )
            }
        }
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Confetti

    private func startConfetti() {
        confettiParticles = (0..<28).map { _ in
            ConfettiParticle(
                x: CGFloat.random(in: 0.05...0.95),
                delay: Double.random(in: 0...0.6),
                color: [Color.red, .blue, .green, .yellow, .orange, .purple, .pink].randomElement()!,
                size: CGFloat.random(in: 6...12),
                drift: CGFloat.random(in: -1...1),
                spin: Double.random(in: 1.5...3.5)
            )
        }
        confettiStart = Date()
        showConfetti = true

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.confettiDuration) {
            showConfetti = false
        }
    }

    /// Confetti is driven by `TimelineView(.animation)`, which asks for a new frame
    /// every display refresh. The previous version drew from `Date()` inside a bare
    /// `Canvas` and tried to force redraws with a `Timer` that only ever invalidated
    /// itself — nothing invalidated the view, so the burst rendered as a single
    /// frozen frame at a random point in its arc.
    private var confettiOverlay: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let elapsed = timeline.date.timeIntervalSince(confettiStart)

                for particle in confettiParticles {
                    let progress = (elapsed - particle.delay) / Self.confettiFallSeconds
                    guard progress > 0, progress < 1 else { continue }

                    let x = particle.x * size.width + sin(progress * .pi * particle.spin) * 26 * particle.drift
                    let y = progress * (size.height + 40) - 20
                    let rect = CGRect(x: x, y: y, width: particle.size, height: particle.size)

                    context.fill(
                        Path(ellipseIn: rect),
                        // Hold full opacity through most of the fall, then fade out
                        // over the last third so pieces don't vanish mid-screen.
                        with: .color(particle.color.opacity(min(1, (1 - progress) * 3)))
                    )
                }
            }
        }
    }

    private static let confettiFallSeconds: Double = 1.9
    private static let confettiDuration: Double = 2.8
}

// MARK: - Confetti Particle

struct ConfettiParticle: Identifiable {
    let id = UUID()
    /// Horizontal start position as a fraction of the canvas width.
    let x: CGFloat
    let delay: Double
    let color: Color
    let size: CGFloat
    /// Signed multiplier on the horizontal sway, so pieces don't move in lockstep.
    let drift: CGFloat
    /// Number of sway half-cycles over the fall.
    let spin: Double
}

// MARK: - Deletion Preview Grid

/// Simple grid of photos queued for deletion, for quick review before final delete.
struct DeletionPreviewGrid: View {
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
                        AssetThumbnailView(asset: photo.asset)
                            .aspectRatio(1, contentMode: .fill)
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
