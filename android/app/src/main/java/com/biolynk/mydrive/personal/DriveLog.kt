package com.biolynk.mydrive.personal

import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.time.DayOfWeek
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

/** One drive. Local only (P3). Timestamps are epoch milliseconds. */
data class Drive(val id: String, val startTs: Long, val endTs: Long, val distanceKm: Double, val startLabel: String, val endLabel: String) {
    val minutes get() = ((endTs - startTs) / 60_000.0).coerceAtLeast(0.0)

    fun toJson(): JSONObject = JSONObject().put("id", id).put("startTs", startTs).put("endTs", endTs)
        .put("distanceKm", distanceKm).put("startLabel", startLabel).put("endLabel", endLabel)

    companion object {
        fun fromJson(o: JSONObject) = Drive(o.getString("id"), o.getLong("startTs"), o.getLong("endTs"),
            o.getDouble("distanceKm"), o.getString("startLabel"), o.getString("endLabel"))
    }
}

data class UsualStop(
    val label: String, val count: Int, val dayOfWeek: DayOfWeek, val hour: Int,
    val avgMinutes: Int, val arrivalMinuteOfDay: Int,
) {
    /** "Clinic at 9:30 — 32 min" */
    fun line(): String = "$label at ${arrivalMinuteOfDay / 60}:${"%02d".format(arrivalMinuteOfDay % 60)} — $avgMinutes min"
}

data class Route(val from: String, val to: String, val count: Int)

/** Pure maths over a list of drives. */
object DriveStats {
    const val USUAL_STOP_MIN_VISITS = 3

    private fun slotOf(ts: Long, zone: ZoneId) = Instant.ofEpochMilli(ts).atZone(zone).let { it.dayOfWeek to it.hour }

    /** End labels seen at least 3 times, with their typical weekday + start hour (most frequent pair). Most visited first. */
    fun usualStops(drives: List<Drive>, zone: ZoneId = ZoneId.systemDefault()): List<UsualStop> =
        drives.filter { it.endLabel.isNotBlank() }.groupBy { it.endLabel }
            .filter { it.value.size >= USUAL_STOP_MIN_VISITS }
            .map { (label, ds) ->
                val slot = ds.groupingBy { slotOf(it.startTs, zone) }.eachCount().entries
                    .sortedWith(compareByDescending<Map.Entry<Pair<DayOfWeek, Int>, Int>> { it.value }
                        .thenBy { it.key.first }.thenBy { it.key.second }).first().key
                val inSlot = ds.filter { slotOf(it.startTs, zone) == slot }
                val arrival = inSlot.map { d -> Instant.ofEpochMilli(d.endTs).atZone(zone).let { it.hour * 60 + it.minute } }.average().toInt()
                UsualStop(label, ds.size, slot.first, slot.second, inSlot.map { it.minutes }.average().toInt().coerceAtLeast(1), arrival)
            }.sortedWith(compareByDescending<UsualStop> { it.count }.thenBy { it.label })

    /**
     * The usual stop (>= 3 visits) that this weekday and hour (+/- 1 h) is a habit for: some past drive to it
     * left on the same weekday within an hour of now. ETA and arrival come from those matching drives.
     */
    fun usualStopNow(drives: List<Drive>, nowMs: Long, zone: ZoneId = ZoneId.systemDefault()): UsualStop? {
        val now = Instant.ofEpochMilli(nowMs).atZone(zone)
        return usualStops(drives, zone).firstNotNullOfOrNull { stop ->
            val match = drives.filter { d ->
                d.endLabel == stop.label && slotOf(d.startTs, zone).let { (day, h) -> day == now.dayOfWeek && Math.abs(h - now.hour) <= 1 }
            }
            if (match.isEmpty()) null else stop.copy(
                dayOfWeek = now.dayOfWeek, hour = now.hour,
                avgMinutes = match.map { it.minutes }.average().toInt().coerceAtLeast(1),
                arrivalMinuteOfDay = match.map { d -> Instant.ofEpochMilli(d.endTs).atZone(zone).let { it.hour * 60 + it.minute } }.average().toInt())
        }
    }

    /** Consecutive days with a drive, ending today (or yesterday if today has none yet). */
    fun streak(drives: List<Drive>, today: LocalDate, zone: ZoneId = ZoneId.systemDefault()): Int {
        val days = drives.map { Instant.ofEpochMilli(it.startTs).atZone(zone).toLocalDate() }.toSet()
        var d = if (today in days) today else today.minusDays(1)
        var n = 0
        while (d in days) { n++; d = d.minusDays(1) }
        return n
    }

    fun totalKm(drives: List<Drive>) = drives.sumOf { it.distanceKm }

    /** Most frequent start -> end pair; ties go to the alphabetically first. */
    fun favouriteRoute(drives: List<Drive>): Route? =
        drives.filter { it.startLabel.isNotBlank() && it.endLabel.isNotBlank() }
            .groupingBy { it.startLabel to it.endLabel }.eachCount().entries
            .sortedWith(compareByDescending<Map.Entry<Pair<String, String>, Int>> { it.value }
                .thenBy { it.key.first }.thenBy { it.key.second })
            .firstOrNull()?.let { Route(it.key.first, it.key.second, it.value) }

    /** A simulated drive for the debug screen: [daysAgo] days back, leaving at [hour]:00. */
    fun simulated(
        nowMs: Long, daysAgo: Int, hour: Int, from: String, to: String, km: Double, minutes: Int,
        zone: ZoneId = ZoneId.systemDefault(),
    ): Drive {
        val start = Instant.ofEpochMilli(nowMs).atZone(zone).toLocalDate().minusDays(daysAgo.toLong())
            .atTime(hour, 0).atZone(zone).toInstant().toEpochMilli()
        return Drive("sim-$start", start, start + minutes * 60_000L, km, from, to)
    }
}

/** Persists drives for one profile as a JSON array in a file. */
class DriveLogStore(private val file: File) {
    fun all(): List<Drive> = runCatching {
        if (!file.exists()) emptyList() else JSONArray(file.readText()).let { a -> (0 until a.length()).map { Drive.fromJson(a.getJSONObject(it)) } }
    }.getOrDefault(emptyList())

    fun add(d: Drive) = write((all().filter { it.id != d.id } + d).takeLast(MAX_KEPT))
    fun clear() { file.delete() }
    private fun write(ds: List<Drive>) = file.writeText(JSONArray(ds.map { it.toJson() }).toString())

    companion object { const val MAX_KEPT = 500 }
}
