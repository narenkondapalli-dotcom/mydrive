package com.biolynk.mydrive.audio

import android.content.Context
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import com.biolynk.mydrive.car.CarProfile
import com.google.common.util.concurrent.ListenableFuture
import com.google.common.util.concurrent.SettableFuture
import java.io.File
import java.time.LocalTime
import java.util.Locale

/** Builds the spoken briefing and renders it to a WAV file with the phone's text-to-speech. */
object Briefing {

    fun text(profile: CarProfile?, now: LocalTime = LocalTime.now(), nextUp: String? = null): String {
        val part = when {
            now.hour < 12 -> "Good morning"
            now.hour < 17 -> "Good afternoon"
            else -> "Good evening"
        }
        val name = profile?.ownerName.orEmpty()
        return buildList {
            add(if (name.isBlank()) "$part." else "$part, $name.")
            profile?.let { add("Your ${it.displayName} is ready.") }
            nextUp?.let { add("$it.") }
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
