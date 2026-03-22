import SwiftUI

@main
struct SwipeCleanApp: App {
    @StateObject private var permissionManager = PermissionManager()
    @StateObject private var sessionTracker = SessionTracker()
    @StateObject private var albumProvider = AlbumProvider()
    @StateObject private var deleteManager = DeleteManager()
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some Scene {
        WindowGroup {
            if !hasSeenOnboarding {
                OnboardingView(hasSeenOnboarding: $hasSeenOnboarding)
                    .environmentObject(permissionManager)
            } else {
                HomeView()
                    .environmentObject(permissionManager)
                    .environmentObject(sessionTracker)
                    .environmentObject(albumProvider)
                    .environmentObject(deleteManager)
            }
        }
    }
}
