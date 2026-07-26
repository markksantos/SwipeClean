import SwiftUI
import Photos

/// Wraps the app's main content and substitutes an explanatory screen whenever
/// the photo library isn't actually usable.
///
/// Without this, denying the permission prompt leaves the user (and an App
/// Review tester, who will absolutely tap "Don't Allow") staring at an empty
/// home screen with no explanation — the classic guideline 2.1 rejection.
struct PhotoAccessGate<Content: View>: View {
    @EnvironmentObject private var permissionManager: PermissionManager
    @Environment(\.scenePhase) private var scenePhase

    @ViewBuilder var content: () -> Content

    var body: some View {
        Group {
            switch permissionManager.authorizationState {
            case .authorized, .limited:
                content()
            case .denied, .restricted:
                PhotoAccessDeniedView()
            case .notDetermined:
                PhotoAccessRequestView()
            @unknown default:
                PhotoAccessRequestView()
            }
        }
        .onChange(of: scenePhase) { phase in
            // The user may have flipped the switch in Settings and come back.
            if phase == .active {
                permissionManager.checkCurrentStatus()
            }
        }
    }
}

// MARK: - Not Determined

/// Shown when the system prompt hasn't been answered yet — for example the user
/// force-quit during onboarding, or reinstalled the app.
struct PhotoAccessRequestView: View {
    @EnvironmentObject private var permissionManager: PermissionManager

    var body: some View {
        PhotoAccessMessage(
            symbol: "photo.on.rectangle.angled",
            title: "Let SwipeClean see your photos",
            message: "SwipeClean needs access to your photo library so you can swipe through photos and choose which ones to delete. Nothing is ever uploaded, and nothing is deleted until you confirm.",
            actionTitle: "Allow Photo Access"
        ) {
            permissionManager.requestAccess { _ in }
        }
    }
}

// MARK: - Denied / Restricted

/// Shown when access was denied or is blocked by parental controls / MDM.
struct PhotoAccessDeniedView: View {
    @EnvironmentObject private var permissionManager: PermissionManager

    private var isRestricted: Bool {
        permissionManager.authorizationState == .restricted
    }

    var body: some View {
        PhotoAccessMessage(
            symbol: "lock.circle",
            title: isRestricted ? "Photo access is restricted" : "Photo access is off",
            message: isRestricted
                ? "Photo library access is blocked by a restriction on this device, such as Screen Time or a device management profile. SwipeClean can't show your photos until that restriction is lifted."
                : "SwipeClean can't show your photos yet. Turn on photo access in Settings and everything will be here waiting — nothing is uploaded, and nothing is deleted until you confirm.",
            actionTitle: isRestricted ? nil : "Open Settings"
        ) {
            permissionManager.openSettings()
        }
    }
}

// MARK: - Limited Access Banner

/// Sits above the album list when the user granted access to only some photos.
/// Apple expects apps that support limited access to offer a way to change the
/// selection rather than silently showing a near-empty library.
struct LimitedAccessBanner: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "photo.badge.checkmark")
                .font(.title3)
                .foregroundStyle(.orange)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("You've shared some photos")
                    .font(.subheadline.weight(.semibold))
                Text("SwipeClean can only see the photos you picked. Add more to clean the rest of your library.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Button("Manage") {
                PhotoLibraryPresenter.presentLimitedPicker()
            }
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.bordered)
            .accessibilityHint("Choose which photos SwipeClean can access")
        }
        .padding(14)
        .background(Color.orange.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Shared Layout

/// Full-screen explanatory message with an optional call to action.
private struct PhotoAccessMessage: View {
    let symbol: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: symbol)
                .font(.system(size: 56))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            Text(title)
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)

            if let actionTitle {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - UIKit Bridge

enum PhotoLibraryPresenter {
    /// Presents the system sheet for editing the limited-access photo selection.
    static func presentLimitedPicker() {
        guard
            let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
            let root = scene.keyWindow?.rootViewController
        else { return }

        // Walk to the top-most presented controller so the sheet isn't swallowed.
        var presenter = root
        while let presented = presenter.presentedViewController {
            presenter = presented
        }

        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: presenter)
    }
}
