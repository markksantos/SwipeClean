import XCTest
@testable import SwipeClean

// MARK: - SwipeGestureLogic Tests

/// Tests the pure logic extracted from swipe gesture handling.
/// We test calculations (threshold detection, rotation, opacity, velocity)
/// rather than SwiftUI views directly.
final class SwipeGestureLogicTests: XCTestCase {

    // MARK: - Threshold Detection

    func testSwipeRightExceedsThreshold() {
        let result = SwipeGestureCalculator.swipeDirection(
            offset: 130,
            velocity: 0,
            threshold: 120,
            velocityThreshold: 800
        )
        XCTAssertEqual(result, .right)
    }

    func testSwipeLeftExceedsThreshold() {
        let result = SwipeGestureCalculator.swipeDirection(
            offset: -130,
            velocity: 0,
            threshold: 120,
            velocityThreshold: 800
        )
        XCTAssertEqual(result, .left)
    }

    func testSwipeWithinThresholdReturnsNone() {
        let result = SwipeGestureCalculator.swipeDirection(
            offset: 50,
            velocity: 0,
            threshold: 120,
            velocityThreshold: 800
        )
        XCTAssertEqual(result, .none)
    }

    func testSwipeExactlyAtThresholdReturnsNone() {
        let result = SwipeGestureCalculator.swipeDirection(
            offset: 120,
            velocity: 0,
            threshold: 120,
            velocityThreshold: 800
        )
        XCTAssertEqual(result, .none, "Exactly at threshold should not trigger; must exceed it")
    }

    func testNegativeOffsetWithinThresholdReturnsNone() {
        let result = SwipeGestureCalculator.swipeDirection(
            offset: -100,
            velocity: 0,
            threshold: 120,
            velocityThreshold: 800
        )
        XCTAssertEqual(result, .none)
    }

    // MARK: - Velocity-Based Swipe Triggering

    func testHighVelocityRightTriggersSwipeEvenBelowThreshold() {
        let result = SwipeGestureCalculator.swipeDirection(
            offset: 50,
            velocity: 900,
            threshold: 120,
            velocityThreshold: 800
        )
        XCTAssertEqual(result, .right, "High positive velocity should trigger right swipe regardless of offset")
    }

    func testHighVelocityLeftTriggersSwipeEvenBelowThreshold() {
        let result = SwipeGestureCalculator.swipeDirection(
            offset: -50,
            velocity: -900,
            threshold: 120,
            velocityThreshold: 800
        )
        XCTAssertEqual(result, .left, "High negative velocity should trigger left swipe regardless of offset")
    }

    func testVelocityExactlyAtThresholdDoesNotTrigger() {
        let result = SwipeGestureCalculator.swipeDirection(
            offset: 50,
            velocity: 800,
            threshold: 120,
            velocityThreshold: 800
        )
        XCTAssertEqual(result, .none, "Exactly at velocity threshold should not trigger; must exceed it")
    }

    func testVelocityDirectionMustMatchOffset() {
        // Offset is positive (right) but velocity is negative (left) — ambiguous, should not trigger
        let result = SwipeGestureCalculator.swipeDirection(
            offset: 50,
            velocity: -900,
            threshold: 120,
            velocityThreshold: 800
        )
        XCTAssertEqual(result, .none, "Velocity direction must match offset direction")
    }

    // MARK: - Card Rotation Calculation

    func testRotationProportionalToOffset() {
        let rotation = SwipeGestureCalculator.rotation(for: 100)
        XCTAssertEqual(rotation, 5.0, accuracy: 0.01, "100 / 20 = 5 degrees")
    }

    func testRotationCappedAtPositive15() {
        let rotation = SwipeGestureCalculator.rotation(for: 400)
        XCTAssertEqual(rotation, 15.0, accuracy: 0.01, "Rotation must cap at +15°")
    }

    func testRotationCappedAtNegative15() {
        let rotation = SwipeGestureCalculator.rotation(for: -400)
        XCTAssertEqual(rotation, -15.0, accuracy: 0.01, "Rotation must cap at -15°")
    }

    func testRotationZeroAtZeroOffset() {
        let rotation = SwipeGestureCalculator.rotation(for: 0)
        XCTAssertEqual(rotation, 0.0, accuracy: 0.01)
    }

    func testRotationNegativeForLeftSwipe() {
        let rotation = SwipeGestureCalculator.rotation(for: -60)
        XCTAssertEqual(rotation, -3.0, accuracy: 0.01)
    }

    // MARK: - Overlay Opacity Calculation

    func testOverlayOpacityAtZeroOffset() {
        let opacity = SwipeGestureCalculator.overlayOpacity(for: 0, threshold: 120)
        XCTAssertEqual(opacity, 0.0, accuracy: 0.01)
    }

    func testOverlayOpacityAtThreshold() {
        let opacity = SwipeGestureCalculator.overlayOpacity(for: 120, threshold: 120)
        XCTAssertEqual(opacity, 0.7, accuracy: 0.01, "At threshold offset, opacity should reach max 0.7")
    }

    func testOverlayOpacityCapsAt0_7() {
        let opacity = SwipeGestureCalculator.overlayOpacity(for: 300, threshold: 120)
        XCTAssertEqual(opacity, 0.7, accuracy: 0.01, "Opacity must not exceed 0.7")
    }

    func testOverlayOpacityUsesAbsoluteOffset() {
        let opacity = SwipeGestureCalculator.overlayOpacity(for: -60, threshold: 120)
        XCTAssertEqual(opacity, 0.35, accuracy: 0.01, "Opacity should work with negative offsets using abs value")
    }

    func testOverlayOpacityMidway() {
        let opacity = SwipeGestureCalculator.overlayOpacity(for: 60, threshold: 120)
        XCTAssertEqual(opacity, 0.35, accuracy: 0.01, "Half threshold = half max opacity")
    }

    // MARK: - Overlay Scale Calculation

    func testOverlayScaleAtZeroOffset() {
        let scale = SwipeGestureCalculator.overlayScale(for: 0, threshold: 120)
        XCTAssertEqual(scale, 0.8, accuracy: 0.01, "Scale starts at 0.8")
    }

    func testOverlayScaleAtThreshold() {
        let scale = SwipeGestureCalculator.overlayScale(for: 120, threshold: 120)
        XCTAssertEqual(scale, 1.0, accuracy: 0.01, "Scale reaches 1.0 at threshold")
    }

    func testOverlayScaleCapsAt1() {
        let scale = SwipeGestureCalculator.overlayScale(for: 300, threshold: 120)
        XCTAssertEqual(scale, 1.0, accuracy: 0.01)
    }

    // MARK: - Fly-Off Destination

    func testFlyOffRightDestination() {
        let destination = SwipeGestureCalculator.flyOffOffset(direction: .right)
        XCTAssertEqual(destination, 500.0, accuracy: 0.01)
    }

    func testFlyOffLeftDestination() {
        let destination = SwipeGestureCalculator.flyOffOffset(direction: .left)
        XCTAssertEqual(destination, -500.0, accuracy: 0.01)
    }

    func testFlyOffRotationRight() {
        let rotation = SwipeGestureCalculator.flyOffRotation(direction: .right)
        XCTAssertEqual(rotation, 20.0, accuracy: 0.01)
    }

    func testFlyOffRotationLeft() {
        let rotation = SwipeGestureCalculator.flyOffRotation(direction: .left)
        XCTAssertEqual(rotation, -20.0, accuracy: 0.01)
    }
}

// MARK: - CardStackLogic Tests

final class CardStackLogicTests: XCTestCase {

    func testBackCardScaleForSecondCard() {
        let scale = CardStackLayout.scale(forIndex: 1)
        XCTAssertEqual(scale, 0.95, accuracy: 0.01)
    }

    func testBackCardScaleForThirdCard() {
        let scale = CardStackLayout.scale(forIndex: 2)
        XCTAssertEqual(scale, 0.90, accuracy: 0.01)
    }

    func testFrontCardScaleIsFullSize() {
        let scale = CardStackLayout.scale(forIndex: 0)
        XCTAssertEqual(scale, 1.0, accuracy: 0.01)
    }

    func testBackCardOffsetForSecondCard() {
        let offset = CardStackLayout.yOffset(forIndex: 1)
        XCTAssertEqual(offset, 8.0, accuracy: 0.01)
    }

    func testBackCardOffsetForThirdCard() {
        let offset = CardStackLayout.yOffset(forIndex: 2)
        XCTAssertEqual(offset, 16.0, accuracy: 0.01)
    }

    func testFrontCardHasNoOffset() {
        let offset = CardStackLayout.yOffset(forIndex: 0)
        XCTAssertEqual(offset, 0.0, accuracy: 0.01)
    }

    func testMaxVisibleCardsIsThree() {
        XCTAssertEqual(CardStackLayout.maxVisibleCards, 3)
    }
}

// MARK: - Formatting Helpers Tests

final class SwipeFormattingTests: XCTestCase {

    func testFileSizeFormattingBytes() {
        let result = SwipeFormatters.fileSize(bytes: 512)
        XCTAssertEqual(result, "512 B")
    }

    func testFileSizeFormattingKilobytes() {
        let result = SwipeFormatters.fileSize(bytes: 2048)
        XCTAssertEqual(result, "2 KB")
    }

    func testFileSizeFormattingMegabytes() {
        let result = SwipeFormatters.fileSize(bytes: 2_516_582)
        XCTAssertEqual(result, "2.4 MB")
    }

    func testFileSizeFormattingGigabytes() {
        let result = SwipeFormatters.fileSize(bytes: 1_610_612_736)
        XCTAssertEqual(result, "1.5 GB")
    }

    func testDurationFormattingSeconds() {
        let result = SwipeFormatters.duration(seconds: 45)
        XCTAssertEqual(result, "0:45")
    }

    func testDurationFormattingMinutes() {
        let result = SwipeFormatters.duration(seconds: 125)
        XCTAssertEqual(result, "2:05")
    }

    func testDurationFormattingHours() {
        let result = SwipeFormatters.duration(seconds: 3661)
        XCTAssertEqual(result, "1:01:01")
    }

    func testStorageFreedOverOneGBTriggersConfetti() {
        let oneGB: Int64 = 1_073_741_824
        XCTAssertTrue(SessionCompleteLogic.shouldShowConfetti(storageFreed: oneGB + 1))
    }

    func testStorageFreedUnderOneGBNoConfetti() {
        let oneGB: Int64 = 1_073_741_824
        XCTAssertFalse(SessionCompleteLogic.shouldShowConfetti(storageFreed: oneGB - 1))
    }

    func testStorageFreedExactlyOneGBNoConfetti() {
        let oneGB: Int64 = 1_073_741_824
        XCTAssertFalse(SessionCompleteLogic.shouldShowConfetti(storageFreed: oneGB), ">1GB means strictly greater")
    }
}

// MARK: - Undo Logic Tests

final class SwipeUndoTests: XCTestCase {

    private func makeTestPhoto(id: String) -> PhotoItem {
        PhotoItem(
            id: id,
            asset: nil,
            creationDate: nil,
            mediaType: .image,
            fileSize: 1024,
            duration: nil,
            isFavorited: false
        )
    }

    func testUndoShouldRestorePreviousCard() {
        let history = SwipeHistory()
        history.push(action: .deleted, photoId: "photo-1", photo: makeTestPhoto(id: "photo-1"))
        history.push(action: .kept, photoId: "photo-2", photo: makeTestPhoto(id: "photo-2"))

        let undone = history.undo()
        XCTAssertNotNil(undone)
        XCTAssertEqual(undone?.photoId, "photo-2")
        XCTAssertEqual(undone?.action, .kept)
    }

    func testUndoOnEmptyHistoryReturnsNil() {
        let history = SwipeHistory()
        let undone = history.undo()
        XCTAssertNil(undone)
    }

    func testCanUndoReturnsFalseWhenEmpty() {
        let history = SwipeHistory()
        XCTAssertFalse(history.canUndo)
    }

    func testCanUndoReturnsTrueWithHistory() {
        let history = SwipeHistory()
        history.push(action: .deleted, photoId: "photo-1", photo: makeTestPhoto(id: "photo-1"))
        XCTAssertTrue(history.canUndo)
    }

    func testMultipleUndosWorkInOrder() {
        let history = SwipeHistory()
        history.push(action: .deleted, photoId: "photo-1", photo: makeTestPhoto(id: "photo-1"))
        history.push(action: .kept, photoId: "photo-2", photo: makeTestPhoto(id: "photo-2"))
        history.push(action: .deleted, photoId: "photo-3", photo: makeTestPhoto(id: "photo-3"))

        XCTAssertEqual(history.undo()?.photoId, "photo-3")
        XCTAssertEqual(history.undo()?.photoId, "photo-2")
        XCTAssertEqual(history.undo()?.photoId, "photo-1")
        XCTAssertNil(history.undo())
    }

    func testToggleActionReversesDecision() {
        let history = SwipeHistory()
        history.push(action: .deleted, photoId: "photo-1", photo: makeTestPhoto(id: "photo-1"))
        let entryId = history.entries.first!.id

        let toggled = history.toggleAction(for: entryId)
        XCTAssertEqual(toggled?.action, .kept)

        let toggledBack = history.toggleAction(for: entryId)
        XCTAssertEqual(toggledBack?.action, .deleted)
    }
}

// MARK: - Threshold Crossing Detection Tests

final class ThresholdCrossingTests: XCTestCase {

    func testCrossingFromBelowToAboveThreshold() {
        let wasPast = SwipeGestureCalculator.isPastThreshold(offset: 100, threshold: 120)
        let isPast = SwipeGestureCalculator.isPastThreshold(offset: 130, threshold: 120)
        XCTAssertFalse(wasPast)
        XCTAssertTrue(isPast)
    }

    func testCrossingFromAboveToBelowThreshold() {
        let wasPast = SwipeGestureCalculator.isPastThreshold(offset: 130, threshold: 120)
        let isPast = SwipeGestureCalculator.isPastThreshold(offset: 100, threshold: 120)
        XCTAssertTrue(wasPast)
        XCTAssertFalse(isPast)
    }

    func testNegativeThresholdCrossing() {
        let isPast = SwipeGestureCalculator.isPastThreshold(offset: -130, threshold: 120)
        XCTAssertTrue(isPast)
    }
}
