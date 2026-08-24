import Foundation

enum PenPhase: UInt8, Equatable {
    case proximityEnter = 0
    case hover = 1
    case down = 2
    case move = 3
    case up = 4
    case cancel = 5
    case proximityExit = 6
}

enum PenTool: UInt8, Equatable {
    case stylus = 1
    case eraser = 2
}

struct PenSample: Equatable {
    let timestampDeltaUs: UInt32
    let pointerId: UInt16
    let phase: PenPhase
    let tool: PenTool
    let sampleFlags: UInt16
    let buttons: UInt32
    let x: Float
    let y: Float
    let pressure: Float
    let tiltRadians: Float
    let orientationRadians: Float
    let distance: Float
}

struct PenPacket: Equatable {
    let flags: UInt16
    let sequence: UInt32
    let samples: [PenSample]
}

enum PenProtocolError: Error, Equatable {
    case truncated
    case wrongType
    case unsupportedVersion
    case invalidLength
    case invalidSampleCount
    case invalidEnum
    case invalidValue
}

enum PenProtocol {
    static let clientCapabilitiesV1: UInt8 = 12
    static let serverCapabilitiesV1: UInt8 = 12
    static let penEventV1: UInt8 = 13
    static let version: UInt8 = 1
    static let maxSamples = 32
    static let maxPacketSize = 1_227

    private static let headerSize = 6
    private static let payloadPrefixSize = 5
    private static let sampleSize = 38

    static func packetSize(fromPrefix data: Data) throws -> Int {
        guard data.count >= headerSize else { throw PenProtocolError.truncated }
        guard data[0] == penEventV1 else { throw PenProtocolError.wrongType }
        guard data[1] == version else { throw PenProtocolError.unsupportedVersion }
        let payloadLength = Int(readUInt16LE(data, at: 4))
        let total = headerSize + payloadLength
        guard total <= maxPacketSize, payloadLength >= payloadPrefixSize else {
            throw PenProtocolError.invalidLength
        }
        return total
    }

    static func decode(_ data: Data) throws -> PenPacket {
        let totalSize = try packetSize(fromPrefix: data)
        guard data.count == totalSize else { throw PenProtocolError.invalidLength }

        let flags = readUInt16LE(data, at: 2)
        let sequence = readUInt32LE(data, at: 6)
        let sampleCount = Int(data[10])
        guard (1...maxSamples).contains(sampleCount) else { throw PenProtocolError.invalidSampleCount }
        let expectedPayload = payloadPrefixSize + sampleCount * sampleSize
        guard totalSize == headerSize + expectedPayload else { throw PenProtocolError.invalidLength }

        var samples: [PenSample] = []
        samples.reserveCapacity(sampleCount)
        var offset = 11
        for _ in 0..<sampleCount {
            guard let phase = PenPhase(rawValue: data[offset + 6]),
                  let tool = PenTool(rawValue: data[offset + 7]) else {
                throw PenProtocolError.invalidEnum
            }

            let x = readFloatLE(data, at: offset + 14)
            let y = readFloatLE(data, at: offset + 18)
            let pressure = readFloatLE(data, at: offset + 22)
            let tilt = readFloatLE(data, at: offset + 26)
            let orientation = readFloatLE(data, at: offset + 30)
            let distance = readFloatLE(data, at: offset + 34)
            guard x.isFinite, y.isFinite, pressure.isFinite, tilt.isFinite,
                  orientation.isFinite, distance.isFinite,
                  (0...1).contains(x), (0...1).contains(y), (0...1).contains(pressure) else {
                throw PenProtocolError.invalidValue
            }

            samples.append(
                PenSample(
                    timestampDeltaUs: readUInt32LE(data, at: offset),
                    pointerId: readUInt16LE(data, at: offset + 4),
                    phase: phase,
                    tool: tool,
                    sampleFlags: readUInt16LE(data, at: offset + 8),
                    buttons: readUInt32LE(data, at: offset + 10),
                    x: x,
                    y: y,
                    pressure: pressure,
                    tiltRadians: tilt,
                    orientationRadians: orientation,
                    distance: distance
                )
            )
            offset += sampleSize
        }
        return PenPacket(flags: flags, sequence: sequence, samples: samples)
    }

    private static func readUInt16LE(_ data: Data, at offset: Int) -> UInt16 {
        UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }

    private static func readUInt32LE(_ data: Data, at offset: Int) -> UInt32 {
        UInt32(data[offset]) |
            (UInt32(data[offset + 1]) << 8) |
            (UInt32(data[offset + 2]) << 16) |
            (UInt32(data[offset + 3]) << 24)
    }

    private static func readFloatLE(_ data: Data, at offset: Int) -> Float {
        Float(bitPattern: readUInt32LE(data, at: offset))
    }
}
