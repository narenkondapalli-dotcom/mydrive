package com.biolynk.mydrive.audio

import android.content.Context
import android.media.MediaRecorder
import android.os.Build
import com.biolynk.mydrive.personal.LovedOne
import java.io.File

/** Records the loved-one line (phone UI only): AAC in an .m4a, hard-capped at 15 seconds. */
class LovedOneRecorder(private val context: Context) {
    private var recorder: MediaRecorder? = null
    private var target: File? = null

    val isRecording get() = recorder != null

    /** Starts recording into [out]. [onAutoStop] fires when the 15 s cap is reached. Returns false if the mic could not start. */
    fun start(out: File, onAutoStop: () -> Unit): Boolean {
        stopQuietly()
        val r = if (Build.VERSION.SDK_INT >= 31) MediaRecorder(context) else @Suppress("DEPRECATION") MediaRecorder()
        return try {
            r.setAudioSource(MediaRecorder.AudioSource.MIC)
            r.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            r.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            r.setAudioEncodingBitRate(64_000)
            r.setAudioSamplingRate(44_100)
            r.setMaxDuration(LovedOne.MAX_SECONDS * 1000)
            r.setOutputFile(out.path)
            r.setOnInfoListener { _, what, _ ->
                if (what == MediaRecorder.MEDIA_RECORDER_INFO_MAX_DURATION_REACHED) { stop(); onAutoStop() }
            }
            r.prepare(); r.start()
            recorder = r; target = out
            true
        } catch (e: Exception) {
            r.release(); out.delete(); false
        }
    }

    /** Stops and keeps the clip. Returns true if a usable file exists. */
    fun stop(): Boolean {
        val r = recorder ?: return false
        val f = target
        recorder = null; target = null
        return try { r.stop(); r.release(); f != null && f.length() > 0 }
        catch (e: RuntimeException) { r.release(); f?.delete(); false } // stopped too soon: nothing recorded
    }

    private fun stopQuietly() { runCatching { stop() } }
}
