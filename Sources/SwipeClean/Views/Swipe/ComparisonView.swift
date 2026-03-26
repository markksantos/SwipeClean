import SwiftUI
import Photos

// MARK: - ComparisonView

struct ComparisonView: View {
    @EnvironmentObject private var deleteManager: DeleteManager
    @EnvironmentObject private var sessionTracker: SessionTracker
    @Environment(\.dismiss) private var dismiss

    let groups: [SimilarPhotoGroup]

    @State private var currentGroupIndex = 0
    @State private var selectedForDeletion: Set<String> = []
    @State private var totalDeleted = 0
    @State private var totalStorageFreed: Int64 = 0
    @State private var showCompletion = false

    private var currentGroup: SimilarPhotoGroup? {
        guard currentGroupIndex < groups.count else { return nil }
        return groups[currentGroupIndex]
    }

    var body: some View {
        VStack(spacing: 0) {
            if showCompletion {
                completionView
            } else if let group = currentGroup {
                groupReviewView(group)
            } else {
                emptyView
            }
        }
        .navigationTitle("Similar Photos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !showCompletion {
                    Text("Group \(currentGroupIndex + 1) of \(groups.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Group Review

    @ViewBuilder
    private func groupReviewView(_ group: SimilarPhotoGroup) -> some View {
        VStack(spacing: 16) {
            // Progress bar
            ProgressView(value: Double(currentGroupIndex), total: Double(groups.count))
                .tint(.blue)
                .padding(.horizontal)

            // Photos grid
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    ForEach(Array(group.photos.enumerated()), id: \.element.item.id) { index, score in
                        ComparisonCard(
                            score: score,
                            isBest: index == 0,
                            isSelectedForDeletion: selectedForDeletion.contains(score.item.id),
                            onTap: {
                                toggleSelection(score)
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }

            Spacer()

            // Action buttons
            VStack(spacing: 12) {
                if !selectedForDeletion.isEmpty {
                    Button(action: deleteSelectedAndAdvance) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete \(selectedForDeletion.count) & Next")
                        }
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.red)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }

                Button(action: skipGroup) {
                    Text("Skip Group")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Completion

    private var completionView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            Text("All Groups Reviewed!")
                .font(.title2.weight(.bold))

            VStack(spacing: 8) {
                if totalDeleted > 0 {
                    Text("\(totalDeleted) photos queued for deletion")
                        .font(.body)
                        .foregroundStyle(.secondary)

                    Text(SwipeFormatters.fileSize(bytes: totalStorageFreed) + " to be freed")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.blue)
                }

                Text("\(groups.count) groups reviewed")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Button(action: { dismiss() }) {
                Text("Done")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Empty

    private var emptyView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No similar photo groups found")
                .font(.title3.weight(.medium))
            Text("Try a library with more burst or rapid-fire photos.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
    }

    // MARK: - Actions

    private func toggleSelection(_ score: PhotoScore) {
        let id = score.item.id
        if selectedForDeletion.contains(id) {
            selectedForDeletion.remove(id)
        } else {
            selectedForDeletion.insert(id)
        }
    }

    private func deleteSelectedAndAdvance() {
        guard let group = currentGroup else { return }

        for score in group.photos where selectedForDeletion.contains(score.item.id) {
            deleteManager.queueForDeletion(score.item)
            totalDeleted += 1
            totalStorageFreed += score.item.fileSize
        }

        selectedForDeletion.removeAll()
        advanceGroup()
    }

    private func skipGroup() {
        selectedForDeletion.removeAll()
        advanceGroup()
    }

    private func advanceGroup() {
        if currentGroupIndex + 1 < groups.count {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentGroupIndex += 1
            }
            // Pre-select non-best photos for deletion in the next group
            preselectNonBest()
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                showCompletion = true
            }
        }
    }

    private func preselectNonBest() {
        guard let group = currentGroup else { return }
        // Pre-select all photos except the best one for deletion
        selectedForDeletion = Set(group.photos.dropFirst().map(\.item.id))
    }
}

// MARK: - ComparisonCard

private struct ComparisonCard: View {
    let score: PhotoScore
    let isBest: Bool
    let isSelectedForDeletion: Bool
    let onTap: () -> Void

    @State private var thumbnail: UIImage?

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Photo thumbnail
                ZStack(alignment: .topLeading) {
                    Group {
                        if let thumbnail {
                            Image(uiImage: thumbnail)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            Rectangle()
                                .fill(Color(.systemGray5))
                                .overlay {
                                    ProgressView()
                                }
                        }
                    }
                    .frame(height: 180)
                    .clipped()

                    // Overlays
                    VStack(alignment: .leading, spacing: 4) {
                        if isBest {
                            Label("Best", systemImage: "star.fill")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.green)
                                .clipShape(Capsule())
                        }

                        Text("\(Int(score.qualityScore * 100))%")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Capsule())
                    }
                    .padding(8)

                    // Red X overlay for selected-for-deletion
                    if isSelectedForDeletion {
                        Color.red.opacity(0.35)
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundStyle(.white)
                                    .shadow(radius: 2)
                                Spacer()
                            }
                            Spacer()
                        }
                    }
                }

                // Info bar
                VStack(alignment: .leading, spacing: 2) {
                    Text(SwipeFormatters.fileSize(bytes: score.item.fileSize))
                        .font(.caption.weight(.medium))

                    Text(SwipeFormatters.photoDate(score.item.creationDate))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(.secondarySystemGroupedBackground))
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isSelectedForDeletion ? Color.red :
                            (isBest ? Color.green : Color.clear),
                        lineWidth: isSelectedForDeletion || isBest ? 2.5 : 0
                    )
            )
        }
        .buttonStyle(.plain)
        .onAppear { loadThumbnail() }
    }

    private func loadThumbnail() {
        guard let asset = score.item.asset else {
            thumbnail = score.item.thumbnail
            return
        }

        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true

        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: 400, height: 400),
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            if let image {
                self.thumbnail = image
            }
        }
    }
}

// MARK: - SimilarPhotosLoadingView

/// Shown while scanning the photo library for similar groups.
struct SimilarPhotosLoadingView: View {
    @EnvironmentObject private var deleteManager: DeleteManager
    @EnvironmentObject private var sessionTracker: SessionTracker
    @Environment(\.dismiss) private var dismiss

    @State private var groups: [SimilarPhotoGroup]?
    @State private var progress: Float = 0
    @State private var statusMessage = "Preparing..."
    @State private var isAnalyzing = true

    var body: some View {
        Group {
            if let groups, !isAnalyzing {
                ComparisonView(groups: groups)
                    .environmentObject(deleteManager)
                    .environmentObject(sessionTracker)
                    .onAppear {
                        // Pre-select non-best in first group
                        // (handled inside ComparisonView)
                    }
            } else {
                loadingView
            }
        }
        .navigationTitle("Similar Photos")
        .navigationBarTitleDisplayMode(.inline)
        .task { await startAnalysis() }
    }

    private var loadingView: some View {
        VStack(spacing: 24) {
            Spacer()

            ProgressView(value: progress)
                .tint(.blue)
                .padding(.horizontal, 40)

            Text(statusMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding()
    }

    private func startAnalysis() async {
        let finder = SimilarPhotoFinder()
        let result = await finder.findSimilarGroups { pct, message in
            Task { @MainActor in
                progress = pct
                statusMessage = message
            }
        }
        await MainActor.run {
            groups = result
            isAnalyzing = false
        }
    }
}
