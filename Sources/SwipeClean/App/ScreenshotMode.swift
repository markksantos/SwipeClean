#if DEBUG
import Foundation
import Photos

/// Debug-only launch-argument hooks that let the screenshot pipeline put the app
/// on an exact screen without driving the UI.
///
/// `xcrun simctl launch` turns `-key value` arguments into `UserDefaults`, so a
/// capture script can ask for one screen per launch and take a host screenshot
/// once the app settles. That is deterministic and, unlike automating taps,
/// never moves the real pointer.
///
///     xcrun simctl launch <udid> com.nosleeplab.SwipeClean \
///       -hasSeenOnboarding YES -scScreen swipe -scForcePro YES
///
/// The whole file is inside `#if DEBUG`, so none of it exists in the Release
/// build that gets archived for the App Store.
enum ScreenshotMode {

    /// Which screen to open on launch, if any.
    enum Screen: String {
        case home
        case swipe
        case storage
        case achievements
        case paywall
        case settings
        case similar
        case supercut
    }

    static var screen: Screen? {
        guard let raw = UserDefaults.standard.string(forKey: "scScreen") else { return nil }
        return Screen(rawValue: raw)
    }

    /// Treat Pro as unlocked, so the gated features can be photographed for the
    /// store listing without a sandbox purchase on every capture run.
    static var forcesPro: Bool {
        UserDefaults.standard.bool(forKey: "scForcePro")
    }

    /// True whenever the app was launched by the capture script at all.
    static var isActive: Bool { screen != nil || forcesPro }
}

/// Reports photo access as already granted.
///
/// `xcrun simctl privacy grant photos` writes the TCC record — reads of the
/// library do succeed — but `PHPhotoLibrary.authorizationStatus(for: .readWrite)`
/// still answers `.notDetermined` on the iOS 26 simulator. The access gate
/// believes the API, so every capture would otherwise photograph the permission
/// screen instead of the app. This is only reachable from a DEBUG build launched
/// with `-scScreen`.
struct GrantedPermissionProvider: PermissionProviding {
    func authorizationStatus(for accessLevel: PHAccessLevel) -> PHAuthorizationStatus {
        .authorized
    }

    func requestAuthorization(
        for accessLevel: PHAccessLevel,
        handler: @escaping (PHAuthorizationStatus) -> Void
    ) {
        handler(.authorized)
    }
}
#endif
