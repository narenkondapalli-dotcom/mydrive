package com.biolynk.mydrive.data

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import com.biolynk.mydrive.car.CarCatalog
import com.biolynk.mydrive.car.CarProfile
import com.biolynk.mydrive.personal.DriveLogStore
import com.biolynk.mydrive.personal.DriverProfile
import com.biolynk.mydrive.personal.GreetingPicker
import com.biolynk.mydrive.personal.ProfileBook
import java.io.File
import java.util.UUID

/** Small file-based store: profiles (car + driver + ritual), drive logs, loved-one clips, settings. */
class Store(private val context: Context) {
    private val legacyFile get() = File(context.filesDir, "car-profile.json")
    private val bookFile get() = File(context.filesDir, "profiles.json")
    private val prefs = context.getSharedPreferences("mydrive", Context.MODE_PRIVATE)

    val catalog: CarCatalog by lazy {
        CarCatalog.parse(context.assets.open("car-catalog.json").bufferedReader().use { it.readText() })
    }

    val greetings: GreetingPicker by lazy {
        GreetingPicker.parse(context.assets.open("briefing/greetings.json").bufferedReader().use { it.readText() })
    }

    /** Loads all profiles; migrates the first prototype's single car-profile.json once. */
    @Synchronized fun book(): ProfileBook {
        if (bookFile.exists()) runCatching { return ProfileBook.fromJson(bookFile.readText()) }
        if (legacyFile.exists()) {
            val old = runCatching { CarProfile.fromJson(legacyFile.readText()) }.getOrNull()
            if (old != null) return ProfileBook.fromLegacy(old).also { saveBook(it); legacyFile.delete() }
        }
        return ProfileBook()
    }

    @Synchronized fun saveBook(b: ProfileBook) = bookFile.writeText(b.toJson())

    fun active(): DriverProfile? = book().active
    fun loadProfile(): CarProfile? = active()?.car

    /** Adds a new car/driver profile from onboarding and makes it the active one. */
    fun addProfile(car: CarProfile): ProfileBook =
        book().add(DriverProfile(UUID.randomUUID().toString(), car)).also(::saveBook)

    fun driveLog(profileId: String) = DriveLogStore(File(context.filesDir, "drives-$profileId.json"))
    fun lovedOneFile(profileId: String) = File(context.filesDir, "loved-$profileId.m4a")

    var welcomeOnConnect: Boolean
        get() = prefs.getBoolean("welcomeOnConnect", true)
        set(v) = prefs.edit().putBoolean("welcomeOnConnect", v).apply()

    /** Render bitmap for a car+colour; falls back to the placeholder until the full library is bundled/downloaded. */
    fun carBitmap(slug: String, colourId: String): Bitmap? {
        val downloaded = File(context.filesDir, "cars/$slug--$colourId.jpg")
        if (downloaded.exists()) return BitmapFactory.decodeFile(downloaded.path)
        return listOf(CarCatalog.renderAsset(slug, colourId), "cars/placeholder.jpg").firstNotNullOfOrNull { path ->
            runCatching { context.assets.open(path).use(BitmapFactory::decodeStream) }.getOrNull()
        }
    }
}
