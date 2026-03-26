import SwiftUI

/// Grid of all milestones — earned ones highlighted, unearned ones grayed out.
struct AchievementsView: View {
    @EnvironmentObject private var milestoneTracker: MilestoneTracker
    @EnvironmentObject private var sessionTracker: SessionTracker
    @EnvironmentObject private var streakManager: StreakManager

    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Streak summary
                    streakSummary

                    // Milestones by category
                    ForEach(Milestone.Category.allCases, id: \.rawValue) { category in
                        milestoneSection(for: category)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .navigationTitle("Achievements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Streak Summary

    private var streakSummary: some View {
        HStack(spacing: 16) {
            VStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.title)
                    .foregroundStyle(.orange)
                Text("\(streakManager.currentStreak)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                Text("Current Streak")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            Divider()
                .frame(height: 60)

            VStack(spacing: 4) {
                Image(systemName: "trophy.fill")
                    .font(.title)
                    .foregroundStyle(.yellow)
                Text("\(streakManager.bestStreak)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                Text("Best Streak")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color.orange.opacity(0.08), Color.yellow.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Milestone Section

    private func milestoneSection(for category: Milestone.Category) -> some View {
        let milestones = MilestoneTracker.allMilestones.filter { $0.category == category }
        let currentValue = currentValueForCategory(category)

        return VStack(alignment: .leading, spacing: 12) {
            Text(category.rawValue)
                .font(.title3.weight(.semibold))

            // Progress toward next
            if let next = milestoneTracker.nextMilestone(for: category) {
                let progress = milestoneTracker.progress(for: category, currentValue: currentValue)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Next: \(next.title)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(progressLabel(category: category, currentValue: currentValue, threshold: next.threshold))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    ProgressView(value: progress)
                        .tint(tintForCategory(category))
                }
            } else {
                Text("All milestones earned!")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(milestones) { milestone in
                    MilestoneCard(
                        milestone: milestone,
                        isAchieved: milestoneTracker.isAchieved(milestone)
                    )
                }
            }
        }
    }

    // MARK: - Helpers

    private func currentValueForCategory(_ category: Milestone.Category) -> Int64 {
        let stats = sessionTracker.lifetimeStats
        switch category {
        case .photosReviewed:
            return Int64(stats.totalPhotosReviewed)
        case .storageFreed:
            return stats.totalStorageFreed
        case .streakDays:
            return Int64(streakManager.currentStreak)
        }
    }

    private func progressLabel(category: Milestone.Category, currentValue: Int64, threshold: Int64) -> String {
        switch category {
        case .photosReviewed:
            return "\(currentValue) / \(threshold)"
        case .storageFreed:
            return "\(StorageFormatter.humanReadable(bytes: currentValue)) / \(StorageFormatter.humanReadable(bytes: threshold))"
        case .streakDays:
            return "\(currentValue) / \(threshold) days"
        }
    }

    private func tintForCategory(_ category: Milestone.Category) -> Color {
        switch category {
        case .photosReviewed: return .blue
        case .storageFreed: return .green
        case .streakDays: return .orange
        }
    }
}

// MARK: - Milestone Card

struct MilestoneCard: View {
    let milestone: Milestone
    let isAchieved: Bool

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: milestone.icon)
                .font(.system(size: 28))
                .foregroundStyle(isAchieved ? iconColor : .gray.opacity(0.4))

            Text(milestone.title)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Text(milestone.description)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isAchieved ? Color.accentColor.opacity(0.08) : Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isAchieved ? Color.accentColor.opacity(0.2) : Color.clear, lineWidth: 1)
        )
        .opacity(isAchieved ? 1.0 : 0.6)
    }

    private var iconColor: Color {
        switch milestone.category {
        case .photosReviewed: return .blue
        case .storageFreed: return .green
        case .streakDays: return .orange
        }
    }
}

#Preview {
    AchievementsView()
        .environmentObject(MilestoneTracker())
        .environmentObject(SessionTracker())
        .environmentObject(StreakManager())
}
