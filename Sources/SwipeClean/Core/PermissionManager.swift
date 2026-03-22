import Photos
import Combine

/// Production implementation of PermissionProviding that wraps PHPhotoLibrary.
struct LivePermissionProvider: PermissionProviding {
    func authorizationStatus(for accessLevel: PHAccessLevel) -> PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: accessLevel)
    }

    func requestAuthorization(for accessLevel: PHAccessLevel, handler: @escaping (PHAuthorizationStatus) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: accessLevel, handler: handler)
    }
}

/// Manages PHPhotoLibrary authorization and monitors library changes.
final class PermissionManager: NSObject, ObservableObject, PHPhotoLibraryChangeObserver {

    // MARK: - Public State

    @Published private(set) var authorizationState: PHAuthorizationStatus

    /// Fires when the photo library contents change externally.
    let libraryDidChange = PassthroughSubject<PHChange, Never>()

    // MARK: - Private

    private let permissionProvider: PermissionProviding

    // MARK: - Init

    init(permissionProvider: PermissionProviding = LivePermissionProvider()) {
        self.permissionProvider = permissionProvider
        self.authorizationState = permissionProvider.authorizationStatus(for: .readWrite)
        super.init()
    }

    /// Convenience initializer for use as @StateObject (no arguments).
    convenience override init() {
        self.init(permissionProvider: LivePermissionProvider())
        // Register for photo library changes only with the real provider.
        PHPhotoLibrary.shared().register(self)
    }

    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    // MARK: - Public API

    /// Re-checks the current authorization status.
    func checkCurrentStatus() {
        authorizationState = permissionProvider.authorizationStatus(for: .readWrite)
    }

    /// Requests .readWrite photo library access.
    func requestAccess(completion: @escaping (PHAuthorizationStatus) -> Void) {
        permissionProvider.requestAuthorization(for: .readWrite) { [weak self] status in
            DispatchQueue.main.async {
                self?.authorizationState = status
                completion(status)
            }
        }
    }

    /// Whether the user has granted at least limited access.
    var hasAccess: Bool {
        authorizationState == .authorized || authorizationState == .limited
    }

    /// Whether the user needs to go to Settings to grant access.
    var needsSettingsRedirect: Bool {
        authorizationState == .denied || authorizationState == .restricted
    }

    /// Whether access is limited (user selected specific photos only).
    var isLimited: Bool {
        authorizationState == .limited
    }

    // MARK: - PHPhotoLibraryChangeObserver

    func photoLibraryDidChange(_ changeInstance: PHChange) {
        DispatchQueue.main.async { [weak self] in
            self?.libraryDidChange.send(changeInstance)
        }
    }
}
