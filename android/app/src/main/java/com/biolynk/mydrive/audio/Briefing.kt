package com.biolynk.mydrive.audio

import android.content.Context
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import com.biolynk.mydrive.car.CarProfile
import com.biolynk.mydrive.personal.BriefingItems
import com.google.common.util.concurrent.ListenableFuture
import com.google.common.util.concurrent.SettableFuture
import java.io.File
import java.time.LocalTime
import java.util.Locale

/** Builds the spoken briefing and renders it to a WAV file with the phone's text-to-speech. */
object Briefing {

    /**
     * [greeting] (from greetings.json) replaces the built-in hello; [items] gate the optional lines
     * (calendar = [nextUp], usual stop, streak).
     */
    fun text(
        profile: CarProfile?, now: LocalTime = LocalTime.now(), nextUp: String? = null,
        greeting: String? = null, items: BriefingItems = BriefingItems(), usualStop: String? = null, streak: Int = 0,
    ): String {
        val part = when {
            now.hour < 12 -> "Good morning"
            now.hour < 17 -> "Good afternoon"
            else -> "Good evening"
        }
        val name = profile?.ownerName.orEmpty()
        return buildList {
            add(greeting ?: if (name.isBlank()) "$part." else "$part, $name.")
            profile?.let { add("Your ${it.displayName} is ready.") }
            if (items.calendar) nextUp?.let { add("$it.") }
            if (items.usualStop) usualStop?.let { add("$it.") }
            if (items.streak && streak >= 2) add("Day $streak in a row.")
            add("Have a good drive.")
        }.joinToString(" ")
    }

    /** Synthesises [text] to cacheDir/briefing.wav. Completes with the file, or fails. */
    fun synthesize(context: Context, text: String): ListenableFuture<File> {
        val result = SettableFuture.create<File>()
        val out = File(context.cacheDir, "briefing.wav")
        var tts: TextToSpeech? = null
        tts = TextToSpeech(context.applicationContext) { status ->
            val engine = tts ?: return@TextToSpeech
            if (status != TextToSpeech.SUCCESS) {
                result.setException(IllegalStateException("TTS init failed: $status")); return@TextToSpeech
            }
            engine.language = Locale("en", "IN").takeIf { engine.isLanguageAvailable(it) >= 0 } ?: Locale.UK
            engine.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                override fun onStart(id: String?) {}
                override fun onDone(id: String?) { result.set(out); engine.shutdown() }
                @Deprecated("Deprecated in Java")
                override fun onError(id: String?) { result.setException(IllegalStateException("TTS error")); engine.shutdown() }
            })
            engine.synthesizeToFile(text, null, out, "briefing")
        }
        return result
    }
}
