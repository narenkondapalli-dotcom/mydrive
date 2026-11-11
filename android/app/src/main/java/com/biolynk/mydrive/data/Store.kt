package com.biolynk.mydrive.data

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import com.biolynk.mydrive.car.CarCatalog
import com.biolynk.mydrive.car.CarProfile
import java.io.File

/** Small file-based store: car profile + settings. */
class Store(private val context: Context) {
    private val profileFile get() = File(context.filesDir, "car-profile.json")
    private val prefs = context.getSharedPreferences("mydrive", Context.MODE_PRIVATE)

    val catalog: CarCatalog by lazy {
        CarCatalog.parse(context.assets.open("car-catalog.json").bufferedReader().use { it.readText() })
    }

    fun loadProfile(): CarProfile? =
        if (profileFile.exists()) runCatching { CarProfile.fromJson(profileFile.readText()) }.getOrNull() else null

    fun saveProfile(p: CarProfile) = profileFile.writeText(p.toJson())
    fun clearProfile() { profileFile.delete() }

    var welcomeOnConnect: Boolean
        get() = prefs.getBoolean("welcomeOnConnect", true)
        set(v) = prefs.edit().putBoolean("welcomeOnConnect", v).apply()

    var theme: String
        get() = prefs.getString("theme", "signature")!!
        set(v) = prefs.edit().putString("theme", v).apply()

    /** Render bitmap for a car+colour; falls back to the placeholder until the full library is bundled/downloaded. */
    fun carBitmap(slug: String, colourId: String): Bitmap? {
        val downloaded = File(context.filesDir, "cars/$slug--$colourId.jpg")
        if (downloaded.exists()) return BitmapFactory.decodeFile(downloaded.path)
        return listOf(CarCatalog.renderAsset(slug, colourId), "cars/placeholder.jpg").firstNotNullOfOrNull { path ->
            runCatching { context.assets.open(path).use(BitmapFactory::decodeStream) }.getOrNull()
        }
    }
}
