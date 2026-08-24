package com.sidescreen.app

import java.nio.ByteBuffer
import java.nio.ByteOrder

internal enum class PenPhase(val wireValue: Int) {
    PROXIMITY_ENTER(0),
    HOVER(1),
    DOWN(2),
    MOVE(3),
    UP(4),
    CANCEL(5),
    PROXIMITY_EXIT(6),
}

internal enum class PenTool(val wireValue: Int) {
    STYLUS(1),
    ERASER(2),
}

internal data class PenSample(
    val timestampDeltaUs: Long,
    val pointerId: Int,
    val phase: PenPhase,
    val tool: PenTool,
    val sampleFlags: Int,
    val buttons: Long,
    val x: Float,
    val y: Float,
    val pressure: Float,
    val tiltRadians: Float,
    val orientationRadians: Float,
    val distance: Float,
)

internal object PenProtocol {
    const val MESSAGE_CLIENT_CAPABILITIES_V1 = 12
    const val MESSAGE_SERVER_CAPABILITIES_V1 = 12
    const val MESSAGE_PEN_EVENT_V1 = 13
    const val VERSION = 1
    const val MAX_SAMPLES = 32

    private const val SAMPLE_SIZE = 38
    private const val PAYLOAD_PREFIX_SIZE = 5
    private const val HEADER_SIZE = 6

    fun encode(
        sequence: Long,
        samples: List<PenSample>,
        flags: Int = 0,
    ): ByteArray {
        require(samples.isNotEmpty() && samples.size <= MAX_SAMPLES)
        require(sequence in 0..0xFFFF_FFFFL)
        require(flags in 0..0xFFFF)

        val payloadLength = PAYLOAD_PREFIX_SIZE + samples.size * SAMPLE_SIZE
        val buffer = ByteBuffer.allocate(HEADER_SIZE + payloadLength).order(ByteOrder.LITTLE_ENDIAN)
        buffer.put(MESSAGE_PEN_EVENT_V1.toByte())
        buffer.put(VERSION.toByte())
        buffer.putShort(flags.toShort())
        buffer.putShort(payloadLength.toShort())
        buffer.putInt(sequence.toInt())
        buffer.put(samples.size.toByte())

        samples.forEach { sample ->
            require(sample.timestampDeltaUs in 0..0xFFFF_FFFFL)
            require(sample.pointerId in 0..0xFFFF)
            require(sample.sampleFlags in 0..0xFFFF)
            require(sample.buttons in 0..0xFFFF_FFFFL)
            require(sample.x.isFinite() && sample.x in 0f..1f)
            require(sample.y.isFinite() && sample.y in 0f..1f)
            require(sample.pressure.isFinite() && sample.pressure in 0f..1f)
            require(sample.tiltRadians.isFinite())
            require(sample.orientationRadians.isFinite())
            require(sample.distance.isFinite())

            buffer.putInt(sample.timestampDeltaUs.toInt())
            buffer.putShort(sample.pointerId.toShort())
            buffer.put(sample.phase.wireValue.toByte())
            buffer.put(sample.tool.wireValue.toByte())
            buffer.putShort(sample.sampleFlags.toShort())
            buffer.putInt(sample.buttons.toInt())
            buffer.putFloat(sample.x)
            buffer.putFloat(sample.y)
            buffer.putFloat(sample.pressure)
            buffer.putFloat(sample.tiltRadians)
            buffer.putFloat(sample.orientationRadians)
            buffer.putFloat(sample.distance)
        }

        return buffer.array()
    }
}
