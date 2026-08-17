import XCTest
@testable import SideScreen

final class PenEventInjectorTests: XCTestCase {
    func testConvertsScreenUpTiltToNegativeY() {
        let values = PenEventInjector.values(for: sample(tilt: .pi / 4, orientation: 0), contact: true)
        XCTAssertEqual(values.pressure, 0.5, accuracy: 0.0001)
        XCTAssertEqual(values.tiltX, 0, accuracy: 0.0001)
        XCTAssertEqual(values.tiltY, -0.5, accuracy: 0.0001)
        XCTAssertEqual(values.tabletButtons, 1)
    }

    func testMapsAndroidScreenLeftToCoreGraphicsPositiveX() {
        let values = PenEventInjector.values(for: sample(tilt: .pi / 4, orientation: -.pi / 2), contact: false)
        XCTAssertEqual(values.tiltX, 0.5, accuracy: 0.0001)
        XCTAssertEqual(values.tiltY, 0, accuracy: 0.0001)
    }

    func testMapsAndroidScreenRightToCoreGraphicsNegativeX() {
        let values = PenEventInjector.values(for: sample(tilt: .pi / 4, orientation: .pi / 2), contact: false)
        XCTAssertEqual(values.tiltX, -0.5, accuracy: 0.0001)
        XCTAssertEqual(values.tiltY, 0, accuracy: 0.0001)
    }

    func testConvertsScreenDownTiltToPositiveYWithoutInventingTwist() {
        let values = PenEventInjector.values(for: sample(tilt: .pi / 4, orientation: .pi), contact: false)
        XCTAssertEqual(values.tiltX, 0, accuracy: 0.0001)
        XCTAssertEqual(values.tiltY, 0.5, accuracy: 0.0001)
        XCTAssertEqual(values.rotationDegrees, 0)
    }

    func testMapsStylusButtonsAndClampsPressure() {
        let values = PenEventInjector.values(for: sample(pressure: 1, buttons: 32 | 64), contact: true)
        XCTAssertEqual(values.pressure, 1)
        XCTAssertEqual(values.tabletButtons, 7)
    }

    private func sample(
        pressure: Float = 0.5,
        tilt: Float = 0,
        orientation: Float = 0,
        buttons: UInt32 = 0
    ) -> PenSample {
        PenSample(
            timestampDeltaUs: 0,
            pointerId: 0,
            phase: .move,
            tool: .stylus,
            sampleFlags: 0,
            buttons: buttons,
            x: 0.5,
            y: 0.5,
            pressure: pressure,
            tiltRadians: tilt,
            orientationRadians: orientation,
            distance: 0
        )
    }
}
