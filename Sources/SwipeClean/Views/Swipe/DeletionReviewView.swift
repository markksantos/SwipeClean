import SwiftUI
import Photos

/// Review screen shown when the user taps "Done" mid-session.
/// Shows a grid of photos queued for deletion with the option to delete or go back.
struct DeletionReviewView: View {
    @EnvironmentObject var deleteManager: DeleteManager
    @EnvironmentObject var sessionTracker: SessionTracker

    @Environment(\.dismiss) private var dismiss

    @State private var isDeleting = false
    @State private var deleteComplete = false

    private let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 150), spacing: 2)
    ]

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Summary bar
                HStack {
                    Text("\(deleteManager.trashQueue.count) photos")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(SwipeFormatters.fileSize(bytes: deleteManager.queuedStorageBytes))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))

                // Be explicit about where the photos actually go. iOS routes every
                // PhotoKit deletion through Recently Deleted and there is no API to
                // bypass it, so promising anything stronger would be a lie.
                Label(
                    "These move to Recently Deleted in the Photos app. iOS keeps them for 30 days so you can get them back.",
                    systemImage: "clock.arrow.circlepath"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)

                // Photo grid
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(deleteManager.trashQueue, id: \.id) { photo in
                            AssetThumbnailView(asset: photo.asset)
                                .aspectRatio(1, contentMode: .fill)
                        }
                    }
                }

                // Bottom action buttons
                VStack(spacing: 8) {
                    Button {
                        isDeleting = true
                        sessionTracker.endSession()
                        deleteManager.executeQueuedDeletions { _ in
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
                                Text(deleteComplete ? "Deleted" : "Delete \(deleteManager.trashQueue.count) Photos")
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(deleteComplete ? Color.gray : Color(red: 255 / 255, green: 59 / 255, blue: 48 / 255))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(isDeleting || deleteComplete || deleteManager.trashQueue.isEmpty)

                    if deleteComplete {
                        Button {
                            dismiss()
                        } label: {
                            Text("Done")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(Color(.systemGray5))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .navigationTitle("Review Deletions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !deleteComplete {
                        Button("Back") { dismiss() }
                    }
                }
            }
        }
    }
}
