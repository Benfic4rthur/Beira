import XCTest
@testable import BeiraCore

final class EdgeGestureRecognizerTests: XCTestCase {
    private func touch(_ x: Double, _ y: Double, id: Int = 1) -> Contact {
        Contact(id: id, x: x, y: y)
    }
    private func touch(_ y: Double, id: Int = 1) -> Contact { touch(0.01, y, id: id) }

    func testCenterOriginNeverBecomesAnEdgeGesture() {
        var r = EdgeGestureRecognizer(); let c = GestureConfiguration()
        _ = r.process([touch(0.5, 0.4)], configuration: c)
        _ = r.process([touch(0.01, 0.5)], configuration: c)
        XCTAssertFalse(r.process([touch(0.01, 0.7)], configuration: c).isAdjusting)
        _ = r.process([], configuration: c)
        _ = r.process([touch(0.01, 0.4)], configuration: c)
        XCTAssertTrue(r.process([touch(0.01, 0.43)], configuration: c).started)
    }

    func testActivationTravelIsIncludedAndMovementAccumulates() {
        var r = EdgeGestureRecognizer(); var c = GestureConfiguration(); c.stepDistance = 0.025
        _ = r.process([touch(0.4)], configuration: c)
        XCTAssertFalse(r.process([touch(0.41)], configuration: c).isAdjusting)
        let activation = r.process([touch(0.43)], configuration: c)
        XCTAssertTrue(activation.started); XCTAssertEqual(activation.steps, 1)
        XCTAssertEqual(r.process([touch(0.44)], configuration: c).steps, 0)
        let up = r.process([touch(0.46)], configuration: c)
        XCTAssertEqual(up.steps, 1); XCTAssertEqual(up.control, .volume)
        XCTAssertEqual(r.process([touch(0.40)], configuration: c).steps, -2)
    }

    func testRightControlsBrightnessAndCanBeSwapped() {
        var r = EdgeGestureRecognizer(); var c = GestureConfiguration()
        _ = r.process([touch(0.99, 0.4)], configuration: c)
        XCTAssertEqual(r.process([touch(0.99, 0.44)], configuration: c).control, .brightness)
        _ = r.process([], configuration: c)
        c.swapped = true
        _ = r.process([touch(0.99, 0.4)], configuration: c)
        XCTAssertEqual(r.process([touch(0.99, 0.44)], configuration: c).control, .volume)
    }

    func testSecondFingerCancelsUntilEveryFingerLifts() {
        var r = EdgeGestureRecognizer(); let c = GestureConfiguration()
        _ = r.process([touch(0.4)], configuration: c)
        _ = r.process([touch(0.44)], configuration: c)
        let pair = [touch(0.46), touch(0.5, 0.5, id: 2)]
        XCTAssertFalse(r.process(pair, configuration: c).isAdjusting)
        XCTAssertFalse(r.process([touch(0.6)], configuration: c).isAdjusting)
        _ = r.process([], configuration: c)
        _ = r.process([touch(0.4)], configuration: c)
        XCTAssertTrue(r.process([touch(0.44)], configuration: c).started)
    }

    func testTypingOrPauseCannotResumeWithTheSameContact() {
        var r = EdgeGestureRecognizer(); let c = GestureConfiguration()
        _ = r.process([touch(0.4)], configuration: c)
        _ = r.process([touch(0.44)], configuration: c, blocked: true)
        XCTAssertFalse(r.process([touch(0.5)], configuration: c).isAdjusting)
        r.cancelUntilLift()
        XCTAssertFalse(r.process([touch(0.6)], configuration: c).isAdjusting)
    }

    func testHorizontalExitCannotReenterOrSwitchEdges() {
        var r = EdgeGestureRecognizer(); let c = GestureConfiguration()
        _ = r.process([touch(0.4)], configuration: c)
        _ = r.process([touch(0.44)], configuration: c)
        XCTAssertFalse(r.process([touch(0.3, 0.45)], configuration: c).isAdjusting)
        XCTAssertFalse(r.process([touch(0.99, 0.5)], configuration: c).isAdjusting)
    }

    func testInvalidAndLargeFramesAreBoundedToOneFullRange() {
        var r = EdgeGestureRecognizer(); let c = GestureConfiguration()
        _ = r.process([touch(0.2)], configuration: c)
        _ = r.process([touch(0.24)], configuration: c)
        let end = r.process([touch(1.0)], configuration: c)
        XCTAssertEqual(end.limit, .maximum)
        XCTAssertLessThanOrEqual(abs(end.steps), 64)
        XCTAssertFalse(r.process([touch(.nan, 0.5)], configuration: c).isAdjusting)
        XCTAssertFalse(r.process([touch(0.5)], configuration: c).isAdjusting)
    }

    func testBottomRestrictionAndTouchIdentity() {
        var r = EdgeGestureRecognizer(); var c = GestureConfiguration(); c.bottomOnly = true
        _ = r.process([touch(0.8)], configuration: c)
        XCTAssertFalse(r.process([touch(0.2)], configuration: c).isAdjusting)
        _ = r.process([], configuration: c)
        _ = r.process([touch(0.1)], configuration: c)
        XCTAssertFalse(r.process([touch(0.14, id: 2)], configuration: c).isAdjusting)
    }

    func testBreakingAndHoveringContactsDoNotAdjust() {
        var r = EdgeGestureRecognizer(); let c = GestureConfiguration()
        _ = r.process([touch(0.4)], configuration: c)
        _ = r.process([touch(0.44)], configuration: c)
        XCTAssertFalse(r.process([Contact(id: 1, x: 0.01, y: 0.7, state: 5)], configuration: c).isAdjusting)
        XCTAssertFalse(r.process([Contact(id: 1, x: 0.01, y: 0.8, state: 2)], configuration: c).isAdjusting)
    }

    func testFullHeightStrokeReachesBothLimitsForBothControls() {
        for x in [0.01, 0.99] {
            for fine in [true, false] {
                var c = GestureConfiguration(); c.stepDistance = 0.90 / (fine ? 64 : 16)
                var r = EdgeGestureRecognizer()
                _ = r.process([touch(x, 0.97)], configuration: c)
                _ = r.process([touch(x, 0.94)], configuration: c)
                var down = GestureUpdate()
                for y in stride(from: 0.9, through: 0.0, by: -0.05) {
                    let update = r.process([touch(x, y)], configuration: c)
                    if update.limit != nil { down = update }
                }
                XCTAssertEqual(down.limit, .minimum)
                XCTAssertEqual(down.control, x < 0.5 ? .volume : .brightness)
                _ = r.process([], configuration: c)
                _ = r.process([touch(x, 0.02)], configuration: c)
                let up = r.process([touch(x, 0.98)], configuration: c)
                XCTAssertTrue(up.started)
                XCTAssertEqual(up.limit, .maximum)
                XCTAssertEqual(up.control, x < 0.5 ? .volume : .brightness)
            }
        }
    }

    func testEndZoneDoesNotRepeatAndCanBeLeftAndReentered() {
        var r = EdgeGestureRecognizer(); let c = GestureConfiguration()
        _ = r.process([touch(0.8)], configuration: c)
        XCTAssertEqual(r.process([touch(0.95)], configuration: c).limit, .maximum)
        for y in [0.96, 0.98, 0.97, 0.95] {
            let update = r.process([touch(y)], configuration: c)
            XCTAssertNil(update.limit); XCTAssertEqual(update.steps, 0)
        }
        XCTAssertLessThan(r.process([touch(0.85)], configuration: c).steps, 0)
        XCTAssertEqual(r.process([touch(0.97)], configuration: c).limit, .maximum)
    }

    func testRapidAndSlowInteriorStrokesPreserveTheSameTravel() {
        for step in [0.90 / 64, 0.90 / 16] {
            var c = GestureConfiguration(); c.stepDistance = step
            var rapid = EdgeGestureRecognizer(); var slow = EdgeGestureRecognizer()
            _ = rapid.process([touch(0.10)], configuration: c)
            _ = slow.process([touch(0.10)], configuration: c)
            let rapidSteps = rapid.process([touch(0.90)], configuration: c).steps
            var slowSteps = 0
            for i in 1...80 {
                slowSteps += slow.process([touch(0.10 + Double(i) * 0.01)], configuration: c).steps
            }
            XCTAssertEqual(rapidSteps, slowSteps)
            XCTAssertEqual(rapidSteps, Int((0.8 / step).rounded(.towardZero)))
        }
    }

    func testHorizontalStartsStayFreeEvenWhenTurningUpWithinTheBand() {
        var r = EdgeGestureRecognizer(); let c = GestureConfiguration()
        _ = r.process([touch(0.001, 0.4)], configuration: c)
        let horizontal = r.process([touch(0.014, 0.401)], configuration: c)
        XCTAssertFalse(horizontal.isAdjusting); XCTAssertEqual(horizontal.steps, 0)
        let turn = r.process([touch(0.014, 0.7)], configuration: c)
        XCTAssertFalse(turn.isAdjusting); XCTAssertNil(turn.limit)
    }

    func testHorizontalAndMostlyHorizontalDiagonalNeverActivateEitherSide() {
        for x in [0.001, 0.999] {
            var r = EdgeGestureRecognizer(); let c = GestureConfiguration()
            _ = r.process([touch(x, 0.4)], configuration: c)
            let inward = x < 0.5 ? 0.022 : 0.978
            let diagonal = r.process([touch(inward, 0.418)], configuration: c)
            XCTAssertFalse(diagonal.started); XCTAssertFalse(diagonal.isAdjusting)
            XCTAssertEqual(diagonal.steps, 0); XCTAssertNil(diagonal.limit)
        }
    }
}
