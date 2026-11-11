package com.biolynk.mydrive.personal

import org.json.JSONObject

/** Time-of-day greeting copy from shared/briefing/greetings.json ({name} placeholder). */
class GreetingPicker(private val slots: List<Slot>) {
    data class Slot(val key: String, val from: Int, val to: Int, val lines: List<String>) {
        /** Hours are inclusive and may wrap past midnight (21..4). */
        fun covers(hour: Int) = if (from <= to) hour in from..to else hour >= from || hour <= to
    }

    fun slotFor(hour: Int) = slots.firstOrNull { it.covers(hour) }

    /** [variant] picks one of the lines (modulo count) so callers can rotate by day. */
    fun pick(hour: Int, name: String, variant: Int = 0): String {
        val lines = slotFor(hour)?.lines.orEmpty()
        val line = if (lines.isEmpty()) "Hello, {name}." else lines[Math.floorMod(variant, lines.size)]
        val n = name.trim()
        return if (n.isEmpty()) line.replace(", {name}", "").replace(" {name}", "").replace("{name}", "")
        else line.replace("{name}", n)
    }

    companion object {
        fun parse(json: String): GreetingPicker {
            val o = JSONObject(json)
            return GreetingPicker(o.keys().asSequence().map { k ->
                val s = o.getJSONObject(k)
                val h = s.getJSONArray("hours")
                val l = s.getJSONArray("lines")
                Slot(k, h.getInt(0), h.getInt(1), (0 until l.length()).map { l.getString(it) })
            }.toList())
        }
    }
}
