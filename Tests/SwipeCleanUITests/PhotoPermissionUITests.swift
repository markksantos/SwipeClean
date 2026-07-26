import XCTest

/// Answers the system photo-library prompt once, so the screenshot pipeline can
/// run against a real library.
///
/// `xcrun simctl privacy grant photos` writes the TCC record but the iOS 26
/// simulator still shows the prompt, and a system alert belongs to Springboard —
/// nothing in `simctl` can dismiss it, and every screenshot taken while it is up
/// is a photo of the alert. Tapping it from a UI test keeps the whole thing
/// inside the simulator instead of driving the host pointer.
///
/// Reinstalling the app resets its TCC record, so this has to run after an
/// install and before a capture pass. `_pipeline/capture.sh --no-install` then
/// leaves the answer in place.
final class PhotoPermissionUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_grantFullPhotoLibraryAccess() {
        let app = XCUIApplication()
        app.launchArguments = ["-hasSeenOnboarding", "YES"]
        app.launch()

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

        // The prompt is asynchronous: it appears once something touches PhotoKit,
        // which happens as the album list loads rather than at launch.
        let allow = springboard.buttons["Allow Full Access"]
        if allow.waitForExistence(timeout: 20) {
            allow.tap()
        }

        // If the app never asked, access was already granted — either way the
        // library must now be reachable, which the album list proves.
        XCTAssertTrue(
            app.staticTexts["SwipeClean"].waitForExistence(timeout: 20),
            "Home screen should be showing once photo access is settled"
        )
    }
}
