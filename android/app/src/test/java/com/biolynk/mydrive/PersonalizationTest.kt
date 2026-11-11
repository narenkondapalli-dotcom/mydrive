package com.biolynk.mydrive

import com.biolynk.mydrive.audio.Briefing
import com.biolynk.mydrive.car.CarProfile
import com.biolynk.mydrive.look.Accent
import com.biolynk.mydrive.look.Scene
import com.biolynk.mydrive.look.Season
import com.biolynk.mydrive.look.TimeOfDay
import com.biolynk.mydrive.personal.*
import org.junit.Assert.*
import org.junit.Test
import java.io.File
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.ZoneId

class PersonalizationTest {
    private val zone = ZoneId.of("Asia/Kolkata")
    private fun shared(path: String) = File("../../shared/$path").takeIf { it.exists() } ?: File("../shared/$path")
    private fun ts(y: Int, m: Int, d: Int, h: Int, mi: Int = 0) =
        LocalDateTime.of(y, m, d, h, mi).atZone(zone).toInstant().toEpochMilli()
    private fun drive(id: String, from: String, to: String, start: Long, minutes: Int, km: Double = 10.0) =
        Drive(id, start, start + minutes * 60_000L, km, from, to)
    private val car = CarProfile("jeep-meridian", "Jeep", "Meridian", "pearl-white", "Pearl White", "body", "", "Mohit")

    // ---- greeting picker -------------------------------------------------------------------------
    private val picker get() = GreetingPicker.parse(shared("briefing/greetings.json").readText())

    @Test fun everyHourHasAGreetingSlotMatchingTheDayPeriod() {
        for (h in 0..23) assertEquals("hour $h", DayPeriod.ofHour(h).key, picker.slotFor(h)?.key)
    }

    @Test fun greetingBoundariesAndWraparound() {
        assertEquals("morning", picker.slotFor(5)?.key); assertEquals("morning", picker.slotFor(11)?.key)
        assertEquals("afternoon", picker.slotFor(12)?.key); assertEquals("afternoon", picker.slotFor(16)?.key)
        assertEquals("evening", picker.slotFor(17)?.key); assertEquals("evening", picker.slotFor(20)?.key)
        assertEquals("night", picker.slotFor(21)?.key); assertEquals("night", picker.slotFor(0)?.key); assertEquals("night", picker.slotFor(4)?.key)
    }

    @Test fun greetingUsesNameAndRotatesVariant() {
        assertEquals("Good morning, Mohit.", picker.pick(8, "Mohit", 0))
        assertEquals("Morning, Mohit. Let's go.", picker.pick(8, "Mohit", 1))
        assertEquals(picker.pick(8, "Mohit", 0), picker.pick(8, "Mohit", 3)) // 3 morning lines -> wraps
        assertEquals(picker.pick(8, "Mohit", 2), picker.pick(8, "Mohit", -1))
    }

    @Test fun greetingWithoutNameDropsPlaceholder() {
        assertEquals("Good morning.", picker.pick(8, "  ", 0))
        assertEquals("Late one. Drive safe.", picker.pick(23, "", 1))
        for (h in 0..23) assertFalse(picker.pick(h, "").contains("{name}"))
    }

    // ---- briefing items --------------------------------------------------------------------------
    @Test fun briefingItemsToggleLines() {
        val all = Briefing.text(car, LocalTime.of(8, 0), "Meeting at 10", "Good morning, Mohit.", BriefingItems(), "Clinic at 9:30 — 32 min", 5)
        assertTrue(all.contains("Meeting at 10")); assertTrue(all.contains("Clinic at 9:30")); assertTrue(all.contains("Day 5 in a row"))
        val none = Briefing.text(car, LocalTime.of(8, 0), "Meeting at 10", "Good morning, Mohit.",
            BriefingItems(calendar = false, usualStop = false, streak = false), "Clinic at 9:30 — 32 min", 5)
        assertFalse(none.contains("Meeting")); assertFalse(none.contains("Clinic")); assertFalse(none.contains("in a row"))
        assertTrue(none.startsWith("Good morning, Mohit.")); assertTrue(none.endsWith("Have a good drive."))
        assertFalse(Briefing.text(car, LocalTime.of(8, 0), streak = 1).contains("in a row"))
    }

    // ---- drive maths -----------------------------------------------------------------------------
    // 2026-11-11 is a Wednesday.
    private val clinicWeek = (0..4).map { d -> drive("c$d", "Home", "Clinic", ts(2026, 11, 11 - d, 9), 32, 14.0) }

    @Test fun usualStopNeedsThreeVisitsAndKnowsTypicalSlot() {
        assertTrue(DriveStats.usualStops(clinicWeek.take(2), zone).isEmpty())
        val stop = DriveStats.usualStops(clinicWeek, zone).single()
        assertEquals("Clinic", stop.label); assertEquals(5, stop.count)
        assertEquals(9, stop.hour); assertEquals(32, stop.avgMinutes)
        assertEquals("Clinic at 9:32 — 32 min", stop.line())
        // Mon-Wed-Fri-style typical weekday: 3 of 4 visits on Wednesdays wins.
        val mixed = listOf(
            drive("a", "Home", "Gym", ts(2026, 11, 11, 18), 20), drive("b", "Home", "Gym", ts(2026, 11, 4, 18), 20),
            drive("c", "Home", "Gym", ts(2026, 10, 28, 18), 20), drive("d", "Home", "Gym", ts(2026, 11, 6, 7), 20))
        assertEquals(DayOfWeek.WEDNESDAY, DriveStats.usualStops(mixed, zone).single().dayOfWeek)
        assertEquals(18, DriveStats.usualStops(mixed, zone).single().hour)
    }

    @Test fun usualStopNowMatchesWeekdayAndHourWindow() {
        assertEquals("Clinic", DriveStats.usualStopNow(clinicWeek, ts(2026, 11, 18, 9, 40), zone)?.label)  // next Wednesday
        assertEquals("Clinic", DriveStats.usualStopNow(clinicWeek, ts(2026, 11, 18, 10, 5), zone)?.label)  // within 1 h
        assertNull(DriveStats.usualStopNow(clinicWeek, ts(2026, 11, 18, 14, 0), zone))                      // wrong hour
        assertNull(DriveStats.usualStopNow(clinicWeek, ts(2026, 11, 19, 9, 0), zone))                       // Thursday
    }

    @Test fun streakCountsConsecutiveDays() {
        val today = LocalDate.of(2026, 11, 11)
        assertEquals(5, DriveStats.streak(clinicWeek, today, zone))
        assertEquals(0, DriveStats.streak(emptyList(), today, zone))
        // No drive yet today: streak continues from yesterday.
        assertEquals(4, DriveStats.streak(clinicWeek.drop(1), today, zone))
        // A gap breaks it.
        val gap = clinicWeek.filter { it.id != "c2" }
        assertEquals(2, DriveStats.streak(gap, today, zone))
        // Two drives the same day count once.
        assertEquals(1, DriveStats.streak(listOf(clinicWeek[0], drive("x", "A", "B", ts(2026, 11, 11, 17), 10)), today, zone))
        // Old drives only: no streak.
        assertEquals(0, DriveStats.streak(clinicWeek, LocalDate.of(2026, 12, 25), zone))
    }

    @Test fun totalDistanceAndFavouriteRoute() {
        assertEquals(70.0, DriveStats.totalKm(clinicWeek), 0.001)
        assertEquals(0.0, DriveStats.totalKm(emptyList()), 0.0)
        val ds = clinicWeek + drive("o1", "Home", "Office", ts(2026, 11, 3, 8), 25) + drive("o2", "Office", "Home", ts(2026, 11, 3, 18), 25)
        assertEquals(Route("Home", "Clinic", 5), DriveStats.favouriteRoute(ds))
        assertNull(DriveStats.favouriteRoute(emptyList()))
        // Tie -> alphabetical first.
        val tie = listOf(drive("1", "B", "C", 1, 5), drive("2", "A", "D", 2, 5))
        assertEquals(Route("A", "D", 1), DriveStats.favouriteRoute(tie))
    }

    @Test fun simulatedDriveAndStoreRoundTrip() {
        val d = DriveStats.simulated(ts(2026, 11, 11, 12), 2, 9, "Home", "Clinic", 14.2, 32, zone)
        assertEquals(ts(2026, 11, 9, 9), d.startTs); assertEquals(32.0, d.minutes, 0.001)
        assertEquals(d, Drive.fromJson(d.toJson()))
        val f = File.createTempFile("drives", ".json"); f.delete()
        val store = DriveLogStore(f)
        assertTrue(store.all().isEmpty())
        store.add(d); store.add(d) // same id: not duplicated
        assertEquals(listOf(d), store.all())
        store.clear(); assertTrue(store.all().isEmpty())
    }

    // ---- accent + scene --------------------------------------------------------------------------
    @Test fun accentMapsPaintNamesWithGoldFallback() {
        assertEquals(0xFFE0645A.toInt(), Accent.forPaint("Fearless Red"))
        assertEquals(0xFF6C9BEF.toInt(), Accent.forPaint("Galaxy Blue"))
        assertEquals(0xFFEDE7D9.toInt(), Accent.forPaint("Pearl White"))
        assertEquals(0xFFEDE7D9.toInt(), Accent.forPaint("Pearl Arctic White"))
        assertEquals(0xFFBFC8D2.toInt(), Accent.forPaint("Arctic Silver"))
        assertEquals(Accent.GOLD, Accent.forPaint("Coorg Clouds"))
        assertEquals(Accent.GOLD, Accent.forPaint(""))
    }

    @Test fun everyCatalogueColourGetsAnAccent() {
        val json = shared("car-catalog.json").readText()
        val names = Regex("\"name\"\\s*:\\s*\"([^\"]+)\"").findAll(json).map { it.groupValues[1] }.toSet()
        assertTrue(names.size > 100)
        names.forEach { assertEquals(0xFF, Accent.forPaint(it) ushr 24) } // opaque, never throws
    }

    @Test fun scenePicksTimeOfDayAndSeason() {
        assertEquals(TimeOfDay.DAWN, TimeOfDay.ofHour(6)); assertEquals(TimeOfDay.DAY, TimeOfDay.ofHour(12))
        assertEquals(TimeOfDay.DUSK, TimeOfDay.ofHour(18)); assertEquals(TimeOfDay.NIGHT, TimeOfDay.ofHour(22))
        assertEquals(TimeOfDay.NIGHT, TimeOfDay.ofHour(3))
        assertEquals(Season.SUMMER, Season.ofMonth(5)); assertEquals(Season.MONSOON, Season.ofMonth(8))
        assertEquals(Season.WINTER, Season.ofMonth(12)); assertEquals(Season.WINTER, Season.ofMonth(1))
        assertEquals(Scene(TimeOfDay.DUSK, Season.MONSOON), Scene.at(LocalDateTime.of(2026, 8, 1, 18, 0)))
        val dusk = Scene(TimeOfDay.DUSK, Season.SUMMER).gradient
        val night = Scene(TimeOfDay.NIGHT, Season.SUMMER).gradient
        assertNotEquals(dusk, night)
        assertNotEquals(Scene(TimeOfDay.DAY, Season.SUMMER).gradient, Scene(TimeOfDay.DAY, Season.MONSOON).gradient)
    }

    // ---- profiles --------------------------------------------------------------------------------
    private fun dp(id: String, owner: String) = DriverProfile(id, car.copy(ownerName = owner))

    @Test fun profileSwitching() {
        val b = ProfileBook().add(dp("a", "Mohit")).add(dp("b", "Asha"))
        assertEquals("b", b.active?.id) // newest is active
        assertEquals("a", b.switchTo("a").active?.id)
        assertEquals("b", b.switchTo("nope").active?.id) // unknown id: unchanged
        val edited = b.switchTo("a").updateActive { it.copy(ritual = it.ritual.copy(theme = "warm")) }
        assertEquals("warm", edited.active?.ritual?.theme)
        assertEquals("jarvis", edited.profiles.first { it.id == "b" }.ritual.theme) // other profile untouched
        assertEquals("b", edited.remove("a").active?.id)
        assertNull(ProfileBook().remove("x").active)
        assertNull(edited.remove("a").remove("b").active)
    }

    @Test fun profileBookJsonRoundTripAndLegacyMigration() {
        val full = dp("a", "Mohit").copy(
            items = BriefingItems(weather = false, streak = false), ritual = RitualSettings("minimal", 3, false),
            lovedOne = LovedOne("Papa", true, true), style = HomeStyle.STATS)
        val b = ProfileBook().add(full).add(dp("b", "Asha")).switchTo("a")
        assertEquals(b, ProfileBook.fromJson(b.toJson()))
        val legacy = ProfileBook.fromLegacy(car)
        assertEquals(car, legacy.active?.car); assertEquals(RitualSettings(), legacy.active?.ritual)
    }

    // ---- ritual ----------------------------------------------------------------------------------
    @Test fun ritualSettingsAreClampedAndNormalised() {
        assertEquals(0, RitualSettings(delaySeconds = -3).normalised().delaySeconds)
        assertEquals(5, RitualSettings(delaySeconds = 99).normalised().delaySeconds)
        assertEquals("jarvis", RitualSettings(theme = "bogus").normalised().theme)
        val r = RitualSettings("warm", 4, false)
        assertEquals(r, RitualSettings.fromJson(r.toJson()))
        assertEquals(RitualSettings(), RitualSettings.fromJson(null))
        assertTrue(RitualSettings().voice)
    }

    @Test fun lovedOnePlaysOnlyWhenEnabledWithAClip() {
        assertFalse(LovedOne("Papa", enabled = true, hasClip = false).playable)
        assertFalse(LovedOne("Papa", enabled = false, hasClip = true).playable)
        assertTrue(LovedOne("Papa", enabled = true, hasClip = true).playable)
        assertEquals(15, LovedOne.MAX_SECONDS)
    }

    // ---- welcome sounds --------------------------------------------------------------------------
    @Test fun everyThemeAndPeriodResolvesToABundledClip() {
        assertEquals(listOf("jarvis", "warm", "minimal"), WelcomeSounds.THEMES)
        for (theme in WelcomeSounds.THEMES) for (period in DayPeriod.entries) {
            val path = WelcomeSounds.assetPath(theme, period)
            assertEquals("sounds/welcome/$theme-${period.key}.mp3", path)
            assertTrue("missing $path", shared(path).exists())
        }
        for (h in 0..23) assertEquals(WelcomeSounds.assetPath("warm", DayPeriod.ofHour(h)), WelcomeSounds.assetPathForHour("warm", h))
        assertEquals("sounds/welcome/jarvis-night.mp3", WelcomeSounds.assetPathForHour("unknown", 2))
        assertEquals("sounds/welcome/minimal-morning.mp3", WelcomeSounds.assetPathForHour("minimal", 5))
    }

    @Test fun silenceWavHasTheRightLength() {
        val f = File.createTempFile("pause", ".wav")
        WelcomeSounds.writeSilence(f, 3)
        assertEquals(44L + 3 * 16000 * 2, f.length())
        assertEquals("RIFF", String(f.readBytes().copyOfRange(0, 4)))
        WelcomeSounds.writeSilence(f, 0)
        assertEquals(44L, f.length())
    }
}
