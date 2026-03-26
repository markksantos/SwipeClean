import SwiftUI

struct StatsCard: View {
    let photosDeleted: Int
    let storageFreed: Int64
    let currentStreak: Int

    @State private var animatedDeletedCount: Int = 0
    @State private var animatedStorageFreed: Int64 = 0
    @State private var hasAnimated = false

    private var hasActivity: Bool {
        photosDeleted > 0
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Subtle gradient background
            LinearGradient(
                colors: [Color.blue.opacity(0.08), Color.purple.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Decorative sparkle
            Image(systemName: "sparkles")
                .font(.system(size: 28))
                .foregroundStyle(.blue.opacity(0.12))
                .padding(16)

            VStack(spacing: 16) {
                if hasActivity {
                    HStack(spacing: 24) {
                        statColumn(
                            value: "\(animatedDeletedCount)",
                            label: "Photos Cleaned"
                        )
                        Divider()
                            .frame(height: 48)
                        statColumn(
                            value: StorageFormatter.humanReadable(bytes: animatedStorageFreed),
                            label: "Storage Freed"
                        )
                    }

                    // Streak badge
                    if currentStreak > 0 {
                        HStack(spacing: 6) {
                            Image(systemName: "flame.fill")
                                .foregroundStyle(.orange)
                            Text("\(currentStreak) day streak")
                                .font(.subheadline.weight(.medium))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(Capsule())
                    }
                } else {
                    VStack(spacing: 8) {
                        Text("0")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        Text("photos cleaned")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Start swiping to free up space")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(24)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.04), lineWidth: 1)
        )
        .onAppear {
            animateCountUp()
        }
        .onChange(of: photosDeleted) { _ in
            animateCountUp()
        }
        .onChange(of: storageFreed) { _ in
            animateCountUp()
        }
    }

    private func animateCountUp() {
        guard hasActivity else {
            animatedDeletedCount = 0
            animatedStorageFreed = 0
            return
        }

        animatedDeletedCount = 0
        animatedStorageFreed = 0

        let totalSteps = 20
        let stepDuration: TimeInterval = 0.03

        for step in 1...totalSteps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(step)) {
                let fraction = Double(step) / Double(totalSteps)
                // Ease-out curve
                let eased = 1.0 - pow(1.0 - fraction, 3)
                animatedDeletedCount = Int(Double(photosDeleted) * eased)
                animatedStorageFreed = Int64(Double(storageFreed) * eased)
            }
        }
    }

    private func statColumn(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview("With Stats") {
    StatsCard(photosDeleted: 247, storageFreed: 4_800_000_000, currentStreak: 5)
        .padding()
}

#Preview("Zero State") {
    StatsCard(photosDeleted: 0, storageFreed: 0, currentStreak: 0)
        .padding()
}
