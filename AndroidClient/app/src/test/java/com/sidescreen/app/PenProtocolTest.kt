package com.sidescreen.app

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Test

class PenProtocolTest {
    @Test
    fun encodesSharedGoldenVector() {
        val packet =
            PenProtocol.encode(
                sequence = 0x01020304,
                flags = 0x0201,
                samples =
                    listOf(
                        PenSample(
                            timestampDeltaUs = 0x0A0B0C0D,
                            pointerId = 0x1122,
                            phase = PenPhase.DOWN,
                            tool = PenTool.STYLUS,
                            sampleFlags = 0x3344,
                            buttons = 0x55667788,
                            x = 0.25f,
                            y = 0.75f,
                            pressure = 0.5f,
                            tiltRadians = 0.25f,
                            orientationRadians = -0.5f,
                            distance = 0.125f,
                        ),
                    ),
            )

        assertEquals(49, packet.size)
        assertArrayEquals(GOLDEN, packet)
    }

    @Test(expected = IllegalArgumentException::class)
    fun rejectsNaN() {
        PenProtocol.encode(1, listOf(sample(x = Float.NaN)))
    }

    @Test(expected = IllegalArgumentException::class)
    fun rejectsMoreThan32Samples() {
        PenProtocol.encode(1, List(33) { sample() })
    }

    private fun sample(x: Float = 0.5f) =
        PenSample(0, 0, PenPhase.MOVE, PenTool.STYLUS, 0, 0, x, 0.5f, 0.5f, 0f, 0f, 0f)

    companion object {
        private val GOLDEN =
            byteArrayOf(
                0x0D, 0x01, 0x01, 0x02, 0x2B, 0x00,
                0x04, 0x03, 0x02, 0x01, 0x01,
                0x0D, 0x0C, 0x0B, 0x0A, 0x22, 0x11, 0x02, 0x01, 0x44, 0x33,
                0x88.toByte(), 0x77, 0x66, 0x55,
                0x00, 0x00, 0x80.toByte(), 0x3E,
                0x00, 0x00, 0x40, 0x3F,
                0x00, 0x00, 0x00, 0x3F,
                0x00, 0x00, 0x80.toByte(), 0x3E,
                0x00, 0x00, 0x00, 0xBF.toByte(),
                0x00, 0x00, 0x00, 0x3E,
            )
    }
}
