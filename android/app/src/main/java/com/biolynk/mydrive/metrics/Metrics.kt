package com.biolynk.mydrive.metrics

import org.json.JSONObject
import java.io.File
import java.time.Instant
import java.util.concurrent.Executors

/** Built-in measurement: one JSON line per event in filesDir/metrics.jsonl. Same event names as iOS. */
class Metrics(private val file: File, private val build: String = "1", private val now: () -> Long = System::currentTimeMillis) {

    enum class Event(val key: String) {
        CONNECT_DETECTED("connect_detected"), APP_LAUNCHED("app_launched"),
        WELCOME_STARTED("welcome_started"), WELCOME_FINISHED("welcome_finished"),
        BRIEFING_STARTED("briefing_started"), BRIEFING_FINISHED("briefing_finished"),
        HANDOFF_MUSIC("handoff_music"), WIDGET_RENDERED("widget_rendered"),
        ONBOARDING_STEP("onboarding_step"), ONBOARDING_DONE("onboarding_done"), ERROR("error"),
        LOVED_ONE_PLAYED("loved_one_played"), PROFILE_SWITCHED("profile_switched")
    }

    private val io = Executors.newSingleThreadExecutor()
    @Volatile private var connectAt: Long? = null

    fun markConnect(extra: Map<String, String> = emptyMap()) {
        connectAt = now()
        log(Event.CONNECT_DETECTED, extra)
    }

    fun log(event: Event, extra: Map<String, String> = emptyMap()) {
        val line = toJson(event, extra).toString()
        io.execute { file.appendText(line + "\n") }
    }

    fun toJson(event: Event, extra: Map<String, String> = emptyMap()): JSONObject {
        val t = now()
        return JSONObject().apply {
            put("ts", Instant.ofEpochMilli(t).toString())
            put("event", event.key)
            put("platform", "android")
            put("build", build)
            connectAt?.let { put("ms_since_connect", t - it) }
            if (extra.isNotEmpty()) put("extra", JSONObject(extra))
        }
    }

    fun readAll(): String = if (file.exists()) file.readText() else ""
    fun clear() { io.execute { file.delete() } }
    fun flush() { io.submit {}.get() }
}
