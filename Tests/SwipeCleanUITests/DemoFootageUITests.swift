import XCTest

/// Drives the app through a scripted demo so the host can screen-record real
/// footage for the App Preview and social cuts.
///
/// Apple requires an App Preview to be captured from the app in use, so a video
/// assembled from stills is not submittable — and for an app whose whole pitch is
/// a swipe gesture, stills undersell it anyway. Running the gestures from a UI
/// test keeps everything inside the simulator; `xcrun simctl io recordVideo` on
/// the host captures it.
///
///     xcrun simctl io <udid> recordVideo --codec h264 out.mp4 &
///     xcodebuild -scheme SwipeCleanPermission -only-testing:…/DemoFootageUITests test
///     kill -INT %1
final class DemoFootageUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_recordSwipeDemo() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-hasSeenOnboarding", "YES",
            "-scForcePro", "YES",
            "-scScreen", "swipe",
        ]
        app.launch()

        // The deck pushes itself once the album list loads.
        XCTAssertTrue(
            app.staticTexts["All Photos"].waitForExistence(timeout: 25),
            "Swipe screen should open on its own via -scScreen"
        )

        // Let the first card's full-resolution image land before moving.
        sleep(3)

        let swipes = 7

        // Alternate keep and clean so the footage shows both directions and the
        // colour overlays that go with them.
        for index in 0..<swipes {
            drag(in: app, toLeft: index.isMultiple(of: 2))
            // Long enough for the card to fly out and the next one to settle.
            usleep(1_400_000)
        }

        // This doubles as the regression test for the deck dying after one swipe:
        // `SwipeCardView`'s fly-off state used to leak onto the next card, leaving
        // it invisible and rejecting every gesture, so the counter stopped at 2
        // no matter how many times you swiped.
        XCTAssertTrue(
            app.staticTexts["\(swipes + 1) of 18"].waitForExistence(timeout: 5),
            "Deck should have advanced once per swipe, reaching \(swipes + 1) of 18"
        )

        // Rest on the final state so the recording has a clean tail to trim to.
        sleep(2)
    }

    /// Drags across the card with a real press-and-move.
    ///
    /// `XCUIElement.swipeLeft()` does not work here: it is a short flick
    /// delivered to an element's centre, and dispatching it at the window only
    /// registered one swipe in seven — the card's `DragGesture` needs a
    /// translation past its own threshold, which is 120pt at default sensitivity.
    /// A coordinate drag states the distance explicitly.
    private func drag(in app: XCUIApplication, toLeft: Bool) {
        // Both ends stay inside the app's frame. A normalized offset outside 0...1
        // is off-screen and the drag is simply not delivered, which is why an
        // earlier version that dragged to dx -0.35 moved nothing at all.
        let verticalCentreOfCard = 0.42
        let from = toLeft ? 0.82 : 0.18
        let to = toLeft ? 0.06 : 0.94

        let start = app.coordinate(withNormalizedOffset: CGVector(dx: from, dy: verticalCentreOfCard))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: to, dy: verticalCentreOfCard))

        // ~335pt of travel on a 6.9" screen, comfortably past the 120pt threshold,
        // with a long enough initial press for the gesture to latch.
        start.press(
            forDuration: 0.12,
            thenDragTo: end,
            withVelocity: .fast,
            thenHoldForDuration: 0
        )
    }
}
