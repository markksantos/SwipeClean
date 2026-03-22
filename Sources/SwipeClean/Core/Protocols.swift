import Photos
import UIKit

/// Abstracts PHImageManager for testability.
protocol ImageLoading {
    @discardableResult
    func requestImage(
        for asset: PHAsset,
        targetSize: CGSize,
        contentMode: PHImageContentMode,
        options: PHImageRequestOptions?,
        resultHandler: @escaping (UIImage?, [AnyHashable: Any]?) -> Void
    ) -> PHImageRequestID

    func cancelImageRequest(_ requestID: PHImageRequestID)
}

extension PHImageManager: ImageLoading {}

/// Abstracts PHPhotoLibrary.performChanges for testability.
protocol PhotoLibraryPerforming {
    func performChanges(
        _ changeBlock: @escaping @Sendable () -> Void,
        completionHandler: ((Bool, (any Error)?) -> Void)?
    )
}

extension PHPhotoLibrary: PhotoLibraryPerforming {}

/// Abstracts asset fetching for testability.
protocol AssetFetching {
    func fetchAssets(for source: AlbumSource, sortOrder: SortOrder) -> [PHAsset]
    func fetchAlbumSources() -> [AlbumSourceInfo]
}

/// Abstracts PHPhotoLibrary authorization for testability.
protocol PermissionProviding {
    func authorizationStatus(for accessLevel: PHAccessLevel) -> PHAuthorizationStatus
    func requestAuthorization(for accessLevel: PHAccessLevel, handler: @escaping (PHAuthorizationStatus) -> Void)
}

/// Abstracts UserDefaults for testability.
protocol UserDefaultsStoring {
    func integer(forKey key: String) -> Int
    func set(_ value: Int, forKey key: String)
    func double(forKey key: String) -> Double
    func set(_ value: Double, forKey key: String)
    func object(forKey key: String) -> Any?
    func set(_ value: Any?, forKey key: String)
}

extension UserDefaults: UserDefaultsStoring {}
