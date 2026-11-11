package com.biolynk.mydrive.personal

import java.io.File
import java.io.RandomAccessFile

/** Time of day buckets shared with shared/briefing/greetings.json and the welcome clips. */
enum class DayPeriod(val key: String) {
    MORNING("morning"), AFTERNOON("afternoon"), EVENING("evening"), NIGHT("night");

    companion object {
        fun ofHour(hour: Int) = when (hour) {
            in 5..11 -> MORNING
            in 12..16 -> AFTERNOON
            in 17..20 -> EVENING
            else -> NIGHT
        }
    }
}

/** The 12 bundled clips: assets/sounds/welcome/<theme>-<period>.mp3 (copied unchanged from shared/sounds/welcome). */
object WelcomeSounds {
    val THEMES = listOf("jarvis", "warm", "minimal")
    const val DEFAULT_THEME = "jarvis"
    private const val RATE = 16000

    fun assetPath(theme: String, period: DayPeriod) =
        "sounds/welcome/${if (theme in THEMES) theme else DEFAULT_THEME}-${period.key}.mp3"

    fun assetPathForHour(theme: String, hour: Int) = assetPath(theme, DayPeriod.ofHour(hour))

    /** Writes [seconds] of 16 kHz mono 16-bit silence: the ritual pause before the briefing. */
    fun writeSilence(file: File, seconds: Int) {
        val dataBytes = seconds.coerceAtLeast(0) * RATE * 2
        fun le(v: Int) = byteArrayOf(v.toByte(), (v shr 8).toByte(), (v shr 16).toByte(), (v shr 24).toByte())
        RandomAccessFile(file, "rw").use { f ->
            f.setLength(0)
            f.writeBytes("RIFF"); f.write(le(36 + dataBytes)); f.writeBytes("WAVEfmt ")
            f.write(le(16)); f.write(byteArrayOf(1, 0, 1, 0)); f.write(le(RATE)); f.write(le(RATE * 2))
            f.write(byteArrayOf(2, 0, 16, 0)); f.writeBytes("data"); f.write(le(dataBytes))
            f.write(ByteArray(dataBytes))
        }
    }
}
