import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var sessionTracker: SessionTracker
    @EnvironmentObject private var deleteManager: DeleteManager
    @Environment(\.dismiss) private var dismiss

    @AppStorage(SettingsKeys.sortOrder) private var sortOrder: String = PhotoSortOrder.newestFirst.rawValue
    @AppStorage(SettingsKeys.swipeSensitivity) private var swipeSensitivity: String = SwipeSensitivity.medium.rawValue
    @AppStorage(SettingsKeys.hapticFeedback) private var hapticFeedback: Bool = true
    @AppStorage(SettingsKeys.autoPlayVideos) private var autoPlayVideos: Bool = false
    @AppStorage(SettingsKeys.cardStyle) private var cardStyle: String = CardStyle.rounded.rawValue

    @State private var showResetConfirmation = false
    @State private var showClearQueueConfirmation = false

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Sorting
                Section {
                    Picker("Sort photos by", selection: $sortOrder) {
                        ForEach(PhotoSortOrder.allCases) { order in
                            Text(order.displayName).tag(order.rawValue)
                        }
                    }
                } header: {
                    Text("Sorting")
                }

                // MARK: - Behavior
                Section {
                    Picker("Swipe sensitivity", selection: $swipeSensitivity) {
                        ForEach(SwipeSensitivity.allCases) { sensitivity in
                            Text(sensitivity.displayName).tag(sensitivity.rawValue)
                        }
                    }
                    Toggle("Haptic feedback", isOn: $hapticFeedback)
                    Toggle("Auto-play videos", isOn: $autoPlayVideos)
                } header: {
                    Text("Behavior")
                }

                // MARK: - Appearance
                Section {
                    Picker("Card style", selection: $cardStyle) {
                        ForEach(CardStyle.allCases) { style in
                            Text(style.displayName).tag(style.rawValue)
                        }
                    }
                } header: {
                    Text("Appearance")
                }

                // MARK: - Session History
                Section {
                    LabeledContent("Photos Reviewed") {
                        Text(formatNumber(sessionTracker.lifetimeStats.totalPhotosReviewed))
                            .monospacedDigit()
                    }
                    LabeledContent("Photos Cleaned") {
                        Text(formatNumber(sessionTracker.lifetimeStats.totalDeleted))
                            .monospacedDigit()
                    }
                    LabeledContent("Storage Freed") {
                        Text(StorageFormatter.humanReadable(bytes: sessionTracker.lifetimeStats.totalStorageFreed))
                            .monospacedDigit()
                    }
                    LabeledContent("Total Sessions") {
                        Text(formatNumber(sessionTracker.lifetimeStats.totalSessions))
                            .monospacedDigit()
                    }
                    LabeledContent("Longest Streak") {
                        Text("\(formatNumber(sessionTracker.lifetimeStats.longestStreak)) in a row")
                            .monospacedDigit()
                    }
                } header: {
                    Label("Session History", systemImage: "chart.bar.fill")
                }

                // MARK: - Data
                Section {
                    Button(role: .destructive) {
                        showResetConfirmation = true
                    } label: {
                        Label("Reset Statistics", systemImage: "arrow.counterclockwise")
                    }
                    Button(role: .destructive) {
                        showClearQueueConfirmation = true
                    } label: {
                        Label("Clear Deleted Queue", systemImage: "trash.slash")
                    }
                } header: {
                    Text("Data")
                }

                // MARK: - About
                Section {
                    LabeledContent("Version", value: appVersion)
                    LabeledContent("Made by", value: "NoSleepLab")

                    if let rateURL = URL(string: "https://apps.apple.com/app/idXXXXXXXXXX?action=write-review") {
                        Link(destination: rateURL) {
                            Label("Rate SwipeClean", systemImage: "star")
                        }
                    }

                    if let privacyURL = URL(string: "https://nosleeplab.com/privacy") {
                        Link(destination: privacyURL) {
                            Label("Privacy Policy", systemImage: "hand.raised")
                        }
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Reset Statistics?", isPresented: $showResetConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.warning)
                    resetLifetimeStats()
                }
            } message: {
                Text("This will permanently reset all your lifetime statistics. This cannot be undone.")
            }
            .alert("Clear Deleted Queue?", isPresented: $showClearQueueConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) {
                    deleteManager.clearQueue()
                }
            } message: {
                Text("This will remove all photos from the deletion queue without deleting them.")
            }
        }
    }

    /// Formats a number with locale-aware grouping (e.g. 1,234).
    private func formatNumber(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    /// Resets lifetime stats by clearing the persisted UserDefaults keys.
    /// SessionTracker reads from UserDefaults so clearing these keys resets stats to zero.
    private func resetLifetimeStats() {
        let keys = [
            "sc_lifetime_reviewed",
            "sc_lifetime_deleted",
            "sc_lifetime_storage_freed",
            "sc_lifetime_sessions",
            "sc_lifetime_longest_streak"
        ]
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        // Trigger objectWillChange so the UI updates
        sessionTracker.objectWillChange.send()
    }
}

#Preview {
    SettingsView()
}
