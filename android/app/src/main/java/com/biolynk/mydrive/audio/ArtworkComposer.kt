package com.biolynk.mydrive.audio

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.Typeface
import com.biolynk.mydrive.look.Scene
import java.io.ByteArrayOutputStream

/** Square now-playing artwork: car on the dark set + greeting. The part of the car screen we own. */
object ArtworkComposer {
    private const val GOLD = 0xFFD4B97E.toInt()

    fun compose(
        car: Bitmap?, line1: String, line2: String, side: Int = 1024,
        scene: Scene? = null, accent: Int = GOLD,
    ): Bitmap {
        val out = Bitmap.createBitmap(side, side, Bitmap.Config.ARGB_8888)
        val c = Canvas(out)
        val bottom = scene?.gradient?.second ?: Color.rgb(5, 5, 6)
        c.drawColor(Color.rgb(8, 8, 10))
        scene?.let {
            val sky = Paint().apply { shader = LinearGradient(0f, 0f, 0f, side.toFloat(), it.gradient.first, it.gradient.second, Shader.TileMode.CLAMP) }
            c.drawRect(0f, 0f, side.toFloat(), side.toFloat(), sky)
        }
        car?.let {
            val scale = side.toFloat() / it.height
            val w = it.width * scale
            val left = side - w + side * 0.18f
            c.drawBitmap(it, Rect(0, 0, it.width, it.height), RectF(left, 0f, left + w, side.toFloat()), Paint(Paint.FILTER_BITMAP_FLAG))
        }
        val fade = Paint().apply {
            shader = LinearGradient(0f, 0f, side * 0.6f, 0f, bottom, Color.TRANSPARENT, Shader.TileMode.CLAMP)
        }
        c.drawRect(0f, 0f, side * 0.6f, side.toFloat(), fade)

        val serif = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(233, 226, 210); textSize = side * 0.065f
            typeface = Typeface.create(Typeface.SERIF, Typeface.ITALIC)
        }
        val big = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE; textSize = side * 0.13f
            typeface = Typeface.create("sans-serif-thin", Typeface.NORMAL)
        }
        val tag = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = accent; textSize = side * 0.026f; letterSpacing = 0.25f
            typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
        }
        c.drawText(line1, side * 0.07f, side * 0.15f, serif)
        c.drawText(line2, side * 0.07f, side * 0.29f, big)
        c.drawText("MY DRIVE", side * 0.07f, side * 0.92f, tag)
        return out
    }

    fun jpeg(b: Bitmap): ByteArray = ByteArrayOutputStream().also { b.compress(Bitmap.CompressFormat.JPEG, 88, it) }.toByteArray()
}
