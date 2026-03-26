import SwiftUI

/// A scrollable panel showing all swipe decisions in the current session with per-item undo.
struct HistoryPanelView: View {
    @ObservedObject var swipeHistory: SwipeHistory
    @EnvironmentObject var deleteManager: DeleteManager

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Group {
                if swipeHistory.entries.isEmpty {
                    emptyState
                } else {
                    historyList
                }
            }
            .navigationTitle("Swipe History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("No swipe history yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Your swipe decisions will appear here")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - History List

    private var historyList: some View {
        List {
            ForEach(swipeHistory.reversedEntries) { entry in
                historyRow(entry: entry)
            }
        }
        .listStyle(.plain)
    }

    // MARK: - History Row

    private func historyRow(entry: SwipeHistoryEntry) -> some View {
        HStack(spacing: 12) {
            // Thumbnail
            if let thumbnail = entry.photo.thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .frame(width: 50, height: 50)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.tertiary)
                    }
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                actionLabel(for: entry.action)
                Text(formatTime(entry.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Undo button
            Button {
                toggleDecision(entry: entry)
            } label: {
                Text(entry.action == .deleted ? "Restore" : "Delete")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(entry.action == .deleted ? .green : .red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        (entry.action == .deleted ? Color.green : Color.red)
                            .opacity(0.12)
                    )
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Action Label

    private func actionLabel(for action: SwipeAction) -> some View {
        HStack(spacing: 4) {
            Image(systemName: action == .kept ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.caption)
            Text(action == .kept ? "Kept" : "Deleted")
                .font(.subheadline.weight(.medium))
        }
        .foregroundColor(action == .kept ? .green : .red)
    }

    // MARK: - Time Formatter

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }

    // MARK: - Toggle Decision

    private func toggleDecision(entry: SwipeHistoryEntry) {
        let currentAction = entry.action

        // Toggle the action in history
        swipeHistory.toggleAction(for: entry.id)

        // Update the delete manager accordingly
        if currentAction == .deleted {
            // Was deleted, now keeping -- remove from trash
            deleteManager.removeFromTrash(photoId: entry.photoId)
        } else {
            // Was kept, now deleting -- add to trash
            deleteManager.queueForDeletion(entry.photo)
        }
    }
}
