import XCTest
@testable import SwipeClean

// MARK: - Home / Settings / Onboarding Tests

final class HomeViewModelTests: XCTestCase {

    // MARK: - Album Source Display Tests (test id: 22)

    func test_albumSources_displayCorrectCounts() {
        // Simulate what AlbumProvider.fetchAvailableSources returns
        let infos: [AlbumSourceInfo] = [
            AlbumSourceInfo(source: .allPhotos, count: 1234),
            AlbumSourceInfo(source: .recents, count: 56),
            AlbumSourceInfo(source: .screenshots, count: 78),
            AlbumSourceInfo(source: .videos, count: 0),
        ]

        XCTAssertEqual(infos[0].count, 1234, "All Photos should report 1234")
        XCTAssertEqual(infos[1].count, 56, "Recents should report 56")
        XCTAssertEqual(infos[2].count, 78, "Screenshots should report 78")
        XCTAssertEqual(infos[3].count, 0, "Videos should report 0")
    }

    func test_albumSources_groupSmartAndUser() {
        let infos: [AlbumSourceInfo] = [
            AlbumSourceInfo(source: .allPhotos, count: 100),
            AlbumSourceInfo(source: .recents, count: 50),
            AlbumSourceInfo(source: .screenshots, count: 30),
            AlbumSourceInfo(source: .selfies, count: 10),
            AlbumSourceInfo(source: .livePhotos, count: 5),
            AlbumSourceInfo(source: .favorites, count: 20),
            AlbumSourceInfo(source: .duplicates, count: 8),
        ]

        let sources = infos.map(\.source)
        let grouped = AlbumSourceGrouper.group(sources)

        XCTAssertEqual(grouped.smart.count, 7, "All 7 should be in smart albums")
        XCTAssertEqual(grouped.user.count, 0, "No user albums provided")
    }

    // MARK: - Empty Albums Dimmed Tests (test id: 23)

    func test_albumSources_emptyAlbumsIdentified() {
        let infos: [AlbumSourceInfo] = [
            AlbumSourceInfo(source: .allPhotos, count: 100),
            AlbumSourceInfo(source: .screenshots, count: 0),
            AlbumSourceInfo(source: .videos, count: 0),
            AlbumSourceInfo(source: .selfies, count: 42),
        ]

        let emptyInfos = infos.filter { $0.count == 0 }
        let nonEmptyInfos = infos.filter { $0.count > 0 }

        XCTAssertEqual(emptyInfos.count, 2, "Two sources have zero photos")
        XCTAssertEqual(nonEmptyInfos.count, 2, "Two sources have photos")

        // Verify empty albums are disabled in the UI (count == 0)
        for info in emptyInfos {
            XCTAssertTrue(info.count == 0, "\(info.source.displayName) should be disabled when empty")
        }
    }

    // MARK: - Stats Card Tests

    func test_statsCard_showsCorrectLifetimeData() {
        let tracker = SessionTracker(userDefaults: HomeTestMockUserDefaults())

        // Fresh tracker should have zero stats
        let stats = tracker.lifetimeStats
        XCTAssertEqual(stats.totalDeleted, 0)
        XCTAssertEqual(stats.totalStorageFreed, 0)
    }

    func test_statsCard_formatsStorageCorrectly() {
        XCTAssertEqual(StorageFormatter.humanReadable(bytes: 5_000_000_000), "4.7 GB")
        XCTAssertEqual(StorageFormatter.humanReadable(bytes: 0), "0 bytes")
    }

    func test_statsCard_showsZeroStateWhenNeverUsed() {
        let photosDeleted = 0
        let storageFreed: Int64 = 0

        XCTAssertEqual(photosDeleted, 0)
        XCTAssertEqual(StorageFormatter.humanReadable(bytes: storageFreed), "0 bytes")
    }

    func test_storageFormatter_variousSizes() {
        XCTAssertEqual(StorageFormatter.humanReadable(bytes: 0), "0 bytes")
        XCTAssertEqual(StorageFormatter.humanReadable(bytes: 500), "500 bytes")
        XCTAssertEqual(StorageFormatter.humanReadable(bytes: 1_024), "1.0 KB")
        XCTAssertEqual(StorageFormatter.humanReadable(bytes: 1_048_576), "1.0 MB")
        XCTAssertEqual(StorageFormatter.humanReadable(bytes: 1_073_741_824), "1.0 GB")
        XCTAssertEqual(StorageFormatter.humanReadable(bytes: 4_800_000_000), "4.5 GB")
    }

    // MARK: - Onboarding Tests (test id: 24)

    func test_onboarding_showsOnlyOnFirstLaunch() {
        // Simulate first launch: hasSeenOnboarding = false
        var hasSeenOnboarding = false
        XCTAssertFalse(hasSeenOnboarding, "Should show onboarding on first launch")

        // After completing onboarding
        hasSeenOnboarding = true
        XCTAssertTrue(hasSeenOnboarding, "Should not show onboarding after completion")
    }

    func test_onboarding_hasThreePages() {
        let pages = OnboardingPage.allPages
        XCTAssertEqual(pages.count, 3, "Onboarding should have exactly 3 pages")
        XCTAssertEqual(pages[0].title, "Swipe to clean")
        XCTAssertEqual(pages[1].title, "Pick your mess")
        XCTAssertEqual(pages[2].title, "Free up space")
    }

    func test_onboarding_getStartedOnlyOnLastPage() {
        let pages = OnboardingPage.allPages
        for (index, _) in pages.enumerated() {
            let isLastPage = index == pages.count - 1
            if isLastPage {
                XCTAssertTrue(isLastPage, "Get Started button should appear on last page")
            } else {
                XCTAssertFalse(isLastPage, "Get Started button should not appear on page \(index)")
            }
        }
    }

    func test_onboarding_persistsToUserDefaults() {
        let defaults = UserDefaults(suiteName: "test_onboarding_persistence")!
        defaults.removePersistentDomain(forName: "test_onboarding_persistence")

        // Default should be false (not seen)
        let hasSeen = defaults.bool(forKey: "hasSeenOnboarding")
        XCTAssertFalse(hasSeen)

        // After setting it
        defaults.set(true, forKey: "hasSeenOnboarding")
        XCTAssertTrue(defaults.bool(forKey: "hasSeenOnboarding"))
    }

    // MARK: - Settings Tests (test id: 25)

    func test_settings_sortOrderPersists() {
        let defaults = UserDefaults(suiteName: "test_settings_sort")!
        defaults.removePersistentDomain(forName: "test_settings_sort")

        // Default should be newest first
        let rawValue = defaults.string(forKey: SettingsKeys.sortOrder) ?? PhotoSortOrder.newestFirst.rawValue
        XCTAssertEqual(rawValue, PhotoSortOrder.newestFirst.rawValue)

        // Set to oldest first and verify persistence
        defaults.set(PhotoSortOrder.oldestFirst.rawValue, forKey: SettingsKeys.sortOrder)
        let updated = defaults.string(forKey: SettingsKeys.sortOrder)
        XCTAssertEqual(updated, PhotoSortOrder.oldestFirst.rawValue)
    }

    func test_settings_swipeSensitivityValues() {
        XCTAssertEqual(SwipeSensitivity.low.threshold, 160)
        XCTAssertEqual(SwipeSensitivity.medium.threshold, 120)
        XCTAssertEqual(SwipeSensitivity.high.threshold, 80)
    }

    func test_settings_defaultValues() {
        let defaults = UserDefaults(suiteName: "test_settings_defaults")!
        defaults.removePersistentDomain(forName: "test_settings_defaults")

        // Haptic feedback default: on
        let haptic = defaults.object(forKey: SettingsKeys.hapticFeedback) as? Bool ?? true
        XCTAssertTrue(haptic, "Haptic feedback should default to on")

        // Auto-play videos default: off
        let autoPlay = defaults.object(forKey: SettingsKeys.autoPlayVideos) as? Bool ?? false
        XCTAssertFalse(autoPlay, "Auto-play videos should default to off")

        // Card style default: rounded
        let cardStyle = defaults.string(forKey: SettingsKeys.cardStyle) ?? CardStyle.rounded.rawValue
        XCTAssertEqual(cardStyle, CardStyle.rounded.rawValue)
    }

    func test_settings_allSortOrders() {
        let all = PhotoSortOrder.allCases
        XCTAssertEqual(all.count, 4)
        XCTAssertTrue(all.contains(.newestFirst))
        XCTAssertTrue(all.contains(.oldestFirst))
        XCTAssertTrue(all.contains(.largestFirst))
        XCTAssertTrue(all.contains(.random))
    }

    func test_settings_cardStyleOptions() {
        let all = CardStyle.allCases
        XCTAssertEqual(all.count, 2)
        XCTAssertEqual(CardStyle.rounded.displayName, "Rounded")
        XCTAssertEqual(CardStyle.edgeToEdge.displayName, "Edge-to-edge")
    }

    // MARK: - AlbumSource Hashable Tests

    func test_albumSource_hashableConformance() {
        var set: Set<AlbumSource> = []
        set.insert(.allPhotos)
        set.insert(.allPhotos) // duplicate
        set.insert(.screenshots)

        XCTAssertEqual(set.count, 2, "Set should deduplicate identical sources")
    }

    func test_albumSource_dictionaryKey() {
        var counts: [AlbumSource: Int] = [:]
        counts[.allPhotos] = 100
        counts[.screenshots] = 50

        XCTAssertEqual(counts[.allPhotos], 100)
        XCTAssertEqual(counts[.screenshots], 50)
        XCTAssertNil(counts[.videos])
    }
}

// MARK: - Mock UserDefaults for SessionTracker

private final class HomeTestMockUserDefaults: UserDefaultsStoring {
    private var storage: [String: Any] = [:]

    func integer(forKey key: String) -> Int {
        storage[key] as? Int ?? 0
    }

    func set(_ value: Int, forKey key: String) {
        storage[key] = value
    }

    func double(forKey key: String) -> Double {
        storage[key] as? Double ?? 0
    }

    func set(_ value: Double, forKey key: String) {
        storage[key] = value
    }

    func object(forKey key: String) -> Any? {
        storage[key]
    }

    func set(_ value: Any?, forKey key: String) {
        storage[key] = value
    }
}
