package com.biolynk.mydrive.look

import java.time.LocalDateTime

/** P5: the look follows the car. Accent from the paint, artwork scene from time of day + season. */
object Accent {
    const val GOLD = 0xFFD4B97E.toInt()

    private val byWord: Map<String, Long> = mapOf(
        "red" to 0xFFE0645A, "crimson" to 0xFFE0645A, "cherry" to 0xFFE0645A, "ruby" to 0xFFE0645A, "rosso" to 0xFFE0645A,
        "blue" to 0xFF6C9BEF, "oceanic" to 0xFF6C9BEF, "teal" to 0xFF48B3AB, "turquoise" to 0xFF48B3AB,
        "green" to 0xFF62B88C, "forest" to 0xFF62B88C, "emerald" to 0xFF62B88C, "olive" to 0xFF9CAF6A, "avocado" to 0xFF9CAF6A,
        "orange" to 0xFFF0893C, "yellow" to 0xFFE8C84A, "bronze" to 0xFFC9975F, "copper" to 0xFFC9825F,
        "brown" to 0xFFB98A62, "beige" to 0xFFD2BC98, "sienna" to 0xFFC27B4F, "nutmeg" to 0xFFB98A62, "gold" to 0xFFD4B97E,
        "silver" to 0xFFBFC8D2, "grey" to 0xFFA5AFBC, "gray" to 0xFFA5AFBC, "steel" to 0xFFA5AFBC, "graphite" to 0xFF9AA3AE,
        "white" to 0xFFEDE7D9, "pearl" to 0xFFEDE7D9, "ivory" to 0xFFEDE7D9, "black" to 0xFFB5B5C0,
    )

    /** Accent (ARGB) for a paint name such as "Pearl White"; unknown names fall back to gold. */
    fun forPaint(name: String): Int {
        val words = name.lowercase().split(Regex("[^a-z]+")).filter { it.isNotEmpty() }
        // A colour word later in the name wins ("Pearl Arctic White" -> white, "Golden Bronze" -> bronze).
        val hit = words.lastOrNull { it in byWord } ?: return GOLD
        return byWord.getValue(hit).toInt()
    }
}

enum class TimeOfDay {
    DAWN, DAY, DUSK, NIGHT;

    companion object {
        fun ofHour(h: Int) = when (h) {
            in 5..7 -> DAWN
            in 8..16 -> DAY
            in 17..19 -> DUSK
            else -> NIGHT
        }
    }
}

enum class Season {
    SUMMER, MONSOON, WINTER;

    companion object {
        /** Northern India: summer Mar-Jun, monsoon Jul-Sep, winter Oct-Feb. */
        fun ofMonth(m: Int) = when (m) {
            in 3..6 -> SUMMER
            in 7..9 -> MONSOON
            else -> WINTER
        }
    }
}

data class Scene(val timeOfDay: TimeOfDay, val season: Season) {
    /** Gradient (top, bottom) in ARGB behind the car. */
    val gradient: Pair<Int, Int>
        get() {
            val base = when (timeOfDay) {
                TimeOfDay.DAWN -> 0xFF3B2A3FL to 0xFF0E0B10L
                TimeOfDay.DAY -> 0xFF22303FL to 0xFF0A0C10L
                TimeOfDay.DUSK -> 0xFF47281FL to 0xFF0C0809L
                TimeOfDay.NIGHT -> 0xFF0B1020L to 0xFF050507L
            }
            val tint = when (season) {
                Season.SUMMER -> 0xFF2A1A00L
                Season.MONSOON -> 0xFF001A24L
                Season.WINTER -> 0xFF0A1424L
            }
            return mix(base.first, tint, 0.25f).toInt() to base.second.toInt()
        }

    private fun mix(a: Long, b: Long, t: Float): Long {
        fun ch(s: Int) = (((a shr s) and 0xFF) * (1 - t) + ((b shr s) and 0xFF) * t).toLong()
        return 0xFF000000L or (ch(16) shl 16) or (ch(8) shl 8) or ch(0)
    }

    companion object {
        fun at(t: LocalDateTime) = Scene(TimeOfDay.ofHour(t.hour), Season.ofMonth(t.monthValue))
    }
}
