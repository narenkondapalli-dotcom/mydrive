package com.biolynk.mydrive

import com.biolynk.mydrive.audio.Briefing
import com.biolynk.mydrive.car.CarCatalog
import com.biolynk.mydrive.car.CarProfile
import com.biolynk.mydrive.metrics.Metrics
import org.junit.Assert.*
import org.junit.Test
import java.io.File
import java.time.LocalTime

class CoreTest {
    private val catalogJson = File("../../shared/car-catalog.json").takeIf { it.exists() }?.readText()
        ?: File("../shared/car-catalog.json").readText()

    @Test fun catalogHasManufacturerColours() {
        val cat = CarCatalog.parse(catalogJson)
        assertEquals(40, cat.models.size)
        val meridian = cat.find("jeep-meridian")!!
        assertTrue(meridian.colours.any { it.name == "Pearl White" })
        assertTrue(cat.models.all { it.colours.isNotEmpty() })
        assertEquals(cat.models.sumOf { it.colours.size }, cat.models.flatMap { m -> m.colours.map { m.slug + it.id } }.toSet().size)
    }

    @Test fun searchFindsByMakeOrModel() {
        val cat = CarCatalog.parse(catalogJson)
        assertEquals(listOf("jeep-meridian"), cat.search("meridian").map { it.slug })
        assertTrue(cat.search("tata").size >= 4)
    }

    @Test fun profileRoundTrip() {
        val p = CarProfile("jeep-meridian", "Jeep", "Meridian", "pearl-white", "Pearl White", "body", "", "Mohit")
        assertEquals(p, CarProfile.fromJson(p.toJson()))
        assertEquals("Meridian", p.displayName)
    }

    @Test fun metricsHasMsSinceConnect() {
        var t = 1_000L
        val f = File.createTempFile("metrics", ".jsonl")
        val m = Metrics(f, now = { t })
        m.markConnect(); t += 1234
        val j = m.toJson(Metrics.Event.WELCOME_STARTED)
        assertEquals("welcome_started", j.getString("event"))
        assertEquals(1234L, j.getLong("ms_since_connect"))
        m.flush()
        assertEquals(1, f.readLines().size)
    }

    @Test fun briefingGreetsByTimeAndCar() {
        val p = CarProfile("jeep-meridian", "Jeep", "Meridian", "pearl-white", "Pearl White", "body", "", "Mohit")
        val s = Briefing.text(p, LocalTime.of(8, 30), "Clinic at 9:30")
        assertTrue(s.startsWith("Good morning, Mohit."))
        assertTrue(s.contains("Meridian")); assertTrue(s.contains("Clinic at 9:30"))
    }
}
