import XCTest
@testable import SideScreen

final class PenProtocolTests: XCTestCase {
    func testDecodesSharedGoldenVector() throws {
        let packet = try PenProtocol.decode(Data(Self.golden))
        XCTAssertEqual(packet.flags, 0x0201)
        XCTAssertEqual(packet.sequence, 0x01020304)
        XCTAssertEqual(packet.samples.count, 1)
        let sample = try XCTUnwrap(packet.samples.first)
        XCTAssertEqual(sample.timestampDeltaUs, 0x0A0B0C0D)
        XCTAssertEqual(sample.pointerId, 0x1122)
        XCTAssertEqual(sample.phase, .down)
        XCTAssertEqual(sample.tool, .stylus)
        XCTAssertEqual(sample.sampleFlags, 0x3344)
        XCTAssertEqual(sample.buttons, 0x55667788)
        XCTAssertEqual(sample.x, 0.25)
        XCTAssertEqual(sample.y, 0.75)
        XCTAssertEqual(sample.pressure, 0.5)
        XCTAssertEqual(sample.tiltRadians, 0.25)
        XCTAssertEqual(sample.orientationRadians, -0.5)
        XCTAssertEqual(sample.distance, 0.125)
    }

    func testRejectsTruncatedPacket() {
        XCTAssertThrowsError(try PenProtocol.decode(Data(Self.golden.dropLast())))
    }

    func testRejectsNaN() {
        var bytes = Self.golden
        bytes.replaceSubrange(25..<29, with: [0x00, 0x00, 0xC0, 0x7F])
        XCTAssertThrowsError(try PenProtocol.decode(Data(bytes))) { error in
            XCTAssertEqual(error as? PenProtocolError, .invalidValue)
        }
    }

    func testRejectsUnsupportedVersion() {
        var bytes = Self.golden
        bytes[1] = 2
        XCTAssertThrowsError(try PenProtocol.decode(Data(bytes))) { error in
            XCTAssertEqual(error as? PenProtocolError, .unsupportedVersion)
        }
    }

    private static let golden: [UInt8] = [
        0x0D, 0x01, 0x01, 0x02, 0x2B, 0x00,
        0x04, 0x03, 0x02, 0x01, 0x01,
        0x0D, 0x0C, 0x0B, 0x0A, 0x22, 0x11, 0x02, 0x01, 0x44, 0x33,
        0x88, 0x77, 0x66, 0x55,
        0x00, 0x00, 0x80, 0x3E,
        0x00, 0x00, 0x40, 0x3F,
        0x00, 0x00, 0x00, 0x3F,
        0x00, 0x00, 0x80, 0x3E,
        0x00, 0x00, 0x00, 0xBF,
        0x00, 0x00, 0x00, 0x3E,
    ]
}
