import SwiftUI
import UIKit
import StoreKit

struct SettingsView: View {
    @EnvironmentObject private var sessionTracker: SessionTracker
    @EnvironmentObject private var deleteManager: DeleteManager
    @EnvironmentObject private var streakManager: StreakManager
    @EnvironmentObject private var milestoneTracker: MilestoneTracker
    @Environment(\.dismiss) private var dismiss

    @AppStorage(SettingsKeys.sortOrder) private var sortOrder: String = PhotoSortOrder.newestFirst.rawValue
    @AppStorage(SettingsKeys.swipeSensitivity) private var swipeSensitivity: String = SwipeSensitivity.medium.rawValue
    @AppStorage(SettingsKeys.hapticFeedback) private var hapticFeedback: Bool = true
    @AppStorage(SettingsKeys.autoPlayVideos) private var autoPlayVideos: Bool = false
    @AppStorage(SettingsKeys.cardStyle) private var cardStyle: String = CardStyle.rounded.rawValue
    @AppStorage(SettingsKeys.cleanupReminders) private var cleanupReminders: Bool = false
    @AppStorage(SettingsKeys.reminderFrequency) private var reminderFrequency: String = ReminderFrequency.weekly.rawValue

    @State private var showResetConfirmation = false
    @State private var showClearQueueConfirmation = false

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    /// Asks StoreKit for the system rating prompt. iOS rate-limits this, so it
    /// may be a no-op — which is still better than a dead App Store link.
    private func requestAppReview() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else { return }
        SKStoreReviewController.requestReview(in: scene)
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

                // MARK: - Deletion
                Section {
                    LabeledContent("Deleted photos go to", value: "Recently Deleted")
                } header: {
                    Text("Deletion")
                } footer: {
                    Text("SwipeClean never deletes anything until you confirm. Confirmed photos move to the Photos app's Recently Deleted album, where iOS keeps them for 30 days so you can recover them. To free the space immediately, empty Recently Deleted in the Photos app.")
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

                // MARK: - Reminders
                Section {
                    Toggle("Cleanup Reminders", isOn: $cleanupReminders)
                        .onChange(of: cleanupReminders) { enabled in
                            if enabled {
                                let freq = ReminderFrequency(rawValue: reminderFrequency) ?? .weekly
                                ReminderManager.shared.enableReminders(frequency: freq)
                            } else {
                                ReminderManager.shared.disableReminders()
                            }
                        }
                    if cleanupReminders {
                        Picker("Frequency", selection: $reminderFrequency) {
                            ForEach(ReminderFrequency.allCases) { freq in
                                Text(freq.displayName).tag(freq.rawValue)
                            }
                        }
                        .onChange(of: reminderFrequency) { newValue in
                            if cleanupReminders, let freq = ReminderFrequency(rawValue: newValue) {
                                ReminderManager.shared.updateFrequency(freq)
                            }
                        }
                    }
                } header: {
                    Text("Reminders")
                } footer: {
                    Text("Get notified to review and clean up new photos in your library.")
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
                    LabeledContent("Current Streak") {
                        Text("\(formatNumber(streakManager.currentStreak)) days")
                            .monospacedDigit()
                    }
                    LabeledContent("Best Streak") {
                        Text("\(formatNumber(streakManager.bestStreak)) days")
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

                    // Uses the system review prompt rather than a hardcoded App
                    // Store URL, so there is no placeholder ID to go stale.
                    Button {
                        requestAppReview()
                    } label: {
                        Label("Rate SwipeClean", systemImage: "star")
                    }

                    Link(destination: URL(string: "https://nosleeplab.com/swipeclean/privacy")!) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }

                    Link(destination: URL(string: "https://nosleeplab.com/swipeclean/terms")!) {
                        Label("Terms of Use", systemImage: "doc.text")
                    }

                    Link(destination: URL(string: "https://nosleeplab.com/swipeclean/support")!) {
                        Label("Support", systemImage: "questionmark.circle")
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
        streakManager.resetStreak()
        milestoneTracker.resetAll()
    }
}

#Preview {
    SettingsView()
}
