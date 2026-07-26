import SwiftUI

@main
struct SwipeCleanApp: App {
    @StateObject private var permissionManager = PermissionManager()
    @StateObject private var sessionTracker = SessionTracker()
    @StateObject private var albumProvider = AlbumProvider()
    @StateObject private var deleteManager = DeleteManager()
    @StateObject private var streakManager = StreakManager()
    @StateObject private var milestoneTracker = MilestoneTracker()
    // A singleton rather than a fresh instance: StoreKit's `Transaction.updates`
    // stream must be observed by exactly one listener for the life of the process,
    // or an externally-approved purchase can be finished twice.
    @StateObject private var proManager = ProManager.shared
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some Scene {
        WindowGroup {
            if !hasSeenOnboarding {
                OnboardingView(hasSeenOnboarding: $hasSeenOnboarding)
                    .environmentObject(permissionManager)
            } else {
                // Everything past onboarding needs a usable photo library, so the
                // gate decides between the real UI and an explanatory screen.
                PhotoAccessGate {
                    HomeView()
                }
                .environmentObject(permissionManager)
                .environmentObject(sessionTracker)
                .environmentObject(albumProvider)
                .environmentObject(deleteManager)
                .environmentObject(streakManager)
                .environmentObject(milestoneTracker)
                .environmentObject(proManager)
            }
        }
    }
}
