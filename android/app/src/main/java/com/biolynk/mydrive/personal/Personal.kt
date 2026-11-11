package com.biolynk.mydrive.personal

import com.biolynk.mydrive.car.CarProfile
import org.json.JSONArray
import org.json.JSONObject

/** Which lines the spoken briefing may contain (P2). Switches are persisted in the profile. */
data class BriefingItems(
    val weather: Boolean = true, val calendar: Boolean = true, val traffic: Boolean = true,
    val usualStop: Boolean = true, val streak: Boolean = true,
) {
    fun toJson(): JSONObject = JSONObject().put("weather", weather).put("calendar", calendar).put("traffic", traffic)
        .put("usualStop", usualStop).put("streak", streak)

    companion object {
        fun fromJson(o: JSONObject?) = if (o == null) BriefingItems() else BriefingItems(
            o.optBoolean("weather", true), o.optBoolean("calendar", true), o.optBoolean("traffic", true),
            o.optBoolean("usualStop", true), o.optBoolean("streak", true))
    }
}

/** The per-car ritual (P4): welcome sound theme, pause before the briefing, voice on/off. */
data class RitualSettings(val theme: String = WelcomeSounds.DEFAULT_THEME, val delaySeconds: Int = 1, val voice: Boolean = true) {
    /** Always a valid ritual: unknown theme -> default, delay clamped to 0..5 s. */
    fun normalised() = copy(
        theme = if (theme in WelcomeSounds.THEMES) theme else WelcomeSounds.DEFAULT_THEME,
        delaySeconds = delaySeconds.coerceIn(MIN_DELAY, MAX_DELAY))

    fun toJson(): JSONObject = normalised().let { JSONObject().put("theme", it.theme).put("delay", it.delaySeconds).put("voice", it.voice) }

    companion object {
        const val MIN_DELAY = 0
        const val MAX_DELAY = 5
        fun fromJson(o: JSONObject?) = if (o == null) RitualSettings() else
            RitualSettings(o.optString("theme", WelcomeSounds.DEFAULT_THEME), o.optInt("delay", 1), o.optBoolean("voice", true)).normalised()
    }
}

/** The loved-one line (P2): a clip recorded on the phone, played after the welcome sound when enabled. */
data class LovedOne(val label: String = "", val enabled: Boolean = false, val hasClip: Boolean = false) {
    val playable get() = enabled && hasClip
    fun toJson(): JSONObject = JSONObject().put("label", label).put("enabled", enabled).put("hasClip", hasClip)

    companion object {
        const val MAX_SECONDS = 15
        fun fromJson(o: JSONObject?) = if (o == null) LovedOne() else LovedOne(o.optString("label"), o.optBoolean("enabled"), o.optBoolean("hasClip"))
    }
}

/** Phone home layout (P6). The widget uses the same names on iOS. */
enum class HomeStyle(val key: String, val label: String) {
    CAR_LARGE("car-large", "Car large"), MINIMAL("minimal", "Minimal"), STATS("stats", "Stats");

    companion object { fun of(key: String?) = entries.firstOrNull { it.key == key } ?: CAR_LARGE }
}

/** One car + driver: everything personal lives here (P1-P6). */
data class DriverProfile(
    val id: String,
    val car: CarProfile,
    val items: BriefingItems = BriefingItems(),
    val ritual: RitualSettings = RitualSettings(),
    val lovedOne: LovedOne = LovedOne(),
    val style: HomeStyle = HomeStyle.CAR_LARGE,
) {
    fun toJson(): JSONObject = JSONObject().put("id", id).put("car", JSONObject(car.toJson())).put("items", items.toJson())
        .put("ritual", ritual.toJson()).put("lovedOne", lovedOne.toJson()).put("style", style.key)

    companion object {
        fun fromJson(o: JSONObject) = DriverProfile(
            o.getString("id"), CarProfile.fromJson(o.getJSONObject("car").toString()),
            BriefingItems.fromJson(o.optJSONObject("items")), RitualSettings.fromJson(o.optJSONObject("ritual")),
            LovedOne.fromJson(o.optJSONObject("lovedOne")), HomeStyle.of(o.optString("style")))
    }
}

/** All profiles plus which one is active. Immutable: every change returns a new book. */
data class ProfileBook(val profiles: List<DriverProfile> = emptyList(), val activeId: String? = null) {
    val active: DriverProfile? get() = profiles.firstOrNull { it.id == activeId } ?: profiles.firstOrNull()

    /** Adds a profile and makes it the active one. */
    fun add(p: DriverProfile) = copy(profiles = profiles.filter { it.id != p.id } + p, activeId = p.id)

    /** Switches the active profile; an unknown id changes nothing. */
    fun switchTo(id: String) = if (profiles.any { it.id == id }) copy(activeId = id) else this

    fun updateActive(change: (DriverProfile) -> DriverProfile): ProfileBook {
        val cur = active ?: return this
        return copy(profiles = profiles.map { if (it.id == cur.id) change(it) else it }, activeId = cur.id)
    }

    /** Removes a profile; if it was active the first remaining one takes over. */
    fun remove(id: String): ProfileBook {
        val rest = profiles.filter { it.id != id }
        return ProfileBook(rest, if (activeId == id) rest.firstOrNull()?.id else activeId)
    }

    fun toJson(): String = JSONObject().put("active", active?.id ?: JSONObject.NULL)
        .put("profiles", JSONArray(profiles.map { it.toJson() })).toString()

    companion object {
        fun fromJson(s: String): ProfileBook {
            val o = JSONObject(s)
            val arr = o.getJSONArray("profiles")
            return ProfileBook((0 until arr.length()).map { DriverProfile.fromJson(arr.getJSONObject(it)) },
                o.optString("active").takeIf { it.isNotEmpty() && it != "null" })
        }

        /** Migrates the single-car profile written by the first prototype. */
        fun fromLegacy(car: CarProfile) = ProfileBook().add(DriverProfile("p1", car))
    }
}
