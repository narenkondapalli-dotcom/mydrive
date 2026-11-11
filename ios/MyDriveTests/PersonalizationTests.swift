import XCTest
@testable import MyDrive

final class GreetingTests: IsolatedStoreTestCase {
    private let json = """
    {"morning": {"hours": [5, 11], "lines": ["Good morning, {name}.", "Morning, {name}. Lets go."]},
     "afternoon": {"hours": [12, 16], "lines": ["Good afternoon, {name}."]},
     "evening": {"hours": [17, 20], "lines": ["Good evening, {name}."]},
     "night": {"hours": [21, 4], "lines": ["Late one, {name}. Drive safe."]}}
    """

    func testPeriodBoundariesIncludingNightWrap() throws {
        let book = try GreetingBook.parse(Data(json.utf8))
        let expected: [Int: String] = [0: "night", 4: "night", 5: "morning", 11: "morning", 12: "afternoon",
                                       16: "afternoon", 17: "evening", 20: "evening", 21: "night", 23: "night"]
        for (hour, period) in expected { XCTAssertEqual(book.period(forHour: hour), period, "hour \(hour)") }
    }

    func testPickSubstitutesNameAndHonoursChoice() throws {
        let book = try GreetingBook.parse(Data(json.utf8))
        XCTAssertEqual(book.pick(hour: 8, name: "Mohit", index: 1), "Morning, Mohit. Lets go.")
        XCTAssertEqual(book.pick(hour: 8, name: "Mohit", index: nil, seed: 0), "Good morning, Mohit.")
        XCTAssertEqual(book.pick(hour: 8, name: "Mohit", index: nil, seed: 3), "Morning, Mohit. Lets go.")
        XCTAssertEqual(book.pick(hour: 8, name: "Mohit", index: 5), "Morning, Mohit. Lets go.")
    }

    func testEmptyNameDropsPlaceholderCleanly() throws {
        let book = try GreetingBook.parse(Data(json.utf8))
        XCTAssertEqual(book.pick(hour: 14, name: ""), "Good afternoon.")
    }

    func testBundledGreetingsFileLoads() throws {
        let book = try XCTUnwrap(GreetingBook.load())
        XCTAssertEqual(Set(book.slots.keys), ["morning", "afternoon", "evening", "night"])
        for hour in 0..<24 { XCTAssertFalse(book.lines(forHour: hour).isEmpty, "hour \(hour)") }
    }

    func testDayPeriodMatchesGreetingHours() throws {
        let book = try XCTUnwrap(GreetingBook.load())
        for hour in 0..<24 { XCTAssertEqual(book.period(forHour: hour), DayPeriod.at(hour: hour).rawValue, "hour \(hour)") }
    }
}

final class DriveStatsTests: IsolatedStoreTestCase {
    func testTotalDistance() {
        let d = [drive(date(2026, 11, 2), km: 10), drive(date(2026, 11, 3), km: 5.5)]
        XCTAssertEqual(DriveStats.totalDistanceKm(d), 15.5, accuracy: 0.001)
    }

    func testUsualStopNeedsThreeVisits() {
        let two = [drive(date(2026, 11, 2)), drive(date(2026, 11, 9))]
        XCTAssertTrue(DriveStats.usualStops(two, calendar: cal).isEmpty)
        let three = two + [drive(date(2026, 11, 16))]
        let stops = DriveStats.usualStops(three, calendar: cal)
        XCTAssertEqual(stops.count, 1)
        XCTAssertEqual(stops[0].label, "Clinic")
        XCTAssertEqual(stops[0].count, 3)
        XCTAssertEqual(stops[0].hour, 9)
        XCTAssertEqual(stops[0].weekday, cal.component(.weekday, from: date(2026, 11, 2)))
        XCTAssertEqual(stops[0].avgMinutes, 30)
        XCTAssertEqual(stops[0].arrivalMinuteOfDay, 9 * 60 + 30)
    }

    func testUsualStopLineFormat() {
        let stop = UsualStop(label: "Clinic", count: 3, weekday: 2, hour: 9, avgMinutes: 32, arrivalMinuteOfDay: 9 * 60 + 30)
        XCTAssertEqual(DriveStats.usualStopLine(stop), "Clinic at 9:30 — 32 min")
    }

    func testMatchingStopWindow() {
        let drives = (0..<3).map { drive(date(2026, 11, 2 + 7 * $0, 9, 0)) }
        let stops = DriveStats.usualStops(drives, calendar: cal)
        XCTAssertNotNil(DriveStats.matchingStop(stops, now: date(2026, 11, 23, 9, 40), calendar: cal))
        XCTAssertNotNil(DriveStats.matchingStop(stops, now: date(2026, 11, 23, 10, 5), calendar: cal))
        XCTAssertNil(DriveStats.matchingStop(stops, now: date(2026, 11, 23, 12, 0), calendar: cal))
        XCTAssertNil(DriveStats.matchingStop(stops, now: date(2026, 11, 24, 9, 0), calendar: cal))
    }

    func testStreakCases() {
        let today = date(2026, 11, 10, 18)
        XCTAssertEqual(DriveStats.streak([], today: today, calendar: cal), 0)
        let three = (0..<3).map { drive(date(2026, 11, 10 - $0, 8)) }
        XCTAssertEqual(DriveStats.streak(three, today: today, calendar: cal), 3)
        // Still alive if the last drive was yesterday.
        XCTAssertEqual(DriveStats.streak(Array(three.dropFirst()), today: today, calendar: cal), 2)
        // A gap breaks it.
        let gap = [drive(date(2026, 11, 10, 8)), drive(date(2026, 11, 8, 8)), drive(date(2026, 11, 7, 8))]
        XCTAssertEqual(DriveStats.streak(gap, today: today, calendar: cal), 1)
        // Two days ago only: streak over.
        XCTAssertEqual(DriveStats.streak([drive(date(2026, 11, 8, 8))], today: today, calendar: cal), 0)
    }

    func testFavouriteRoute() {
        let d = [drive(date(2026, 11, 2), from: "Home", to: "Clinic"),
                 drive(date(2026, 11, 3), from: "Home", to: "Office"),
                 drive(date(2026, 11, 4), from: "Home", to: "Office"),
                 drive(date(2026, 11, 5), from: "Office", to: "Home")]
        XCTAssertEqual(DriveStats.favouriteRoute(d), RouteStat(start: "Home", end: "Office", count: 2))
        XCTAssertNil(DriveStats.favouriteRoute([]))
    }

    func testSimulatedDrivesBuildUsualStopAndStreak() {
        let now = date(2026, 11, 11, 9, 20)
        let usual = (0..<3).map { SimulatedDrive.make(kind: .usualStop, index: $0, now: now, calendar: cal) }
        let stops = DriveStats.usualStops(usual, calendar: cal)
        XCTAssertEqual(stops.first?.label, "Clinic")
        XCTAssertNotNil(DriveStats.matchingStop(stops, now: now, calendar: cal))
        let streak = (0..<4).map { SimulatedDrive.make(kind: .streak, index: $0, now: now, calendar: cal) }
        XCTAssertEqual(DriveStats.streak(streak, today: now, calendar: cal), 4)
    }

    func testDriveLogPersists() {
        XCTAssertTrue(DriveLogStore.load().isEmpty)
        DriveLogStore.add(drive(date(2026, 11, 2)))
        DriveLogStore.add(drive(date(2026, 11, 3)))
        XCTAssertEqual(DriveLogStore.load().count, 2)
        DriveLogStore.clear()
        XCTAssertTrue(DriveLogStore.load().isEmpty)
    }
}

final class BriefingTests: IsolatedStoreTestCase {
    private let greetings = GreetingBook.fallback

    func testItemsSwitchOnAndOff() {
        let now = date(2026, 11, 23, 9, 30)
        let drives = (0..<3).map { drive(date(2026, 11, 2 + 7 * $0, 9, 0)) }
        let next = SharedStore.NextUp(title: "Meeting at ten", detail: "Leave now", updated: now)
        var p = profile()
        var text = BriefingBuilder.compose(profile: p, nextUp: next, drives: drives, greetings: greetings, now: now, calendar: cal)
        XCTAssertTrue(text.contains("Good morning, Mohit."))
        XCTAssertTrue(text.contains("Meeting at ten. Leave now."))
        XCTAssertTrue(text.contains("Clinic at 9:30 — 30 min."))
        p.briefingItems = []
        text = BriefingBuilder.compose(profile: p, nextUp: next, drives: drives, greetings: greetings, now: now, calendar: cal)
        XCTAssertFalse(text.contains("Meeting"))
        XCTAssertFalse(text.contains("Clinic"))
        XCTAssertTrue(text.contains("Have a good drive."))
    }

    func testStreakLineNeedsTwoDays() {
        let now = date(2026, 11, 10, 18)
        let p = profile()
        let one = [drive(date(2026, 11, 10, 8))]
        XCTAssertFalse(BriefingBuilder.compose(profile: p, nextUp: nil, drives: one, greetings: greetings, now: now, calendar: cal).contains("in a row"))
        let two = one + [drive(date(2026, 11, 9, 8))]
        XCTAssertTrue(BriefingBuilder.compose(profile: p, nextUp: nil, drives: two, greetings: greetings, now: now, calendar: cal).contains("2 days in a row"))
    }
}

final class LookTests: XCTestCase {
    func testAccentFromPaint() {
        XCTAssertEqual(Accent.hex(forPaint: "Galaxy Blue"), "#5B9BD5")
        XCTAssertEqual(Accent.hex(forPaint: "tornado RED"), "#D9534F")
        XCTAssertEqual(Accent.hex(forPaint: "Pearl White"), Accent.fallbackHex)
        XCTAssertEqual(Accent.hex(forPaint: "Brilliant Black"), Accent.fallbackHex)
        XCTAssertEqual(Accent.hex(forPaint: ""), Accent.fallbackHex)
        XCTAssertEqual(Accent.hex(forPaint: "Sacredly Odd"), Accent.fallbackHex)
    }

    func testHexColourParsing() {
        let c = HexColor.rgb("#D4B97E")
        XCTAssertEqual(c.r, 212.0 / 255, accuracy: 0.001)
        XCTAssertEqual(c.b, 126.0 / 255, accuracy: 0.001)
    }

    func testSceneByHourAndMonth() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        func scene(_ m: Int, _ h: Int) -> ArtworkScene {
            ArtworkScene.pick(date: cal.date(from: DateComponents(year: 2026, month: m, day: 15, hour: h))!, calendar: cal)
        }
        XCTAssertEqual(scene(5, 4).timeOfDay, .night)
        XCTAssertEqual(scene(5, 5).timeOfDay, .dawn)
        XCTAssertEqual(scene(5, 8).timeOfDay, .day)
        XCTAssertEqual(scene(5, 16).timeOfDay, .day)
        XCTAssertEqual(scene(5, 17).timeOfDay, .dusk)
        XCTAssertEqual(scene(5, 20).timeOfDay, .night)
        XCTAssertEqual(scene(3, 12).season, .summer)
        XCTAssertEqual(scene(6, 12).season, .summer)
        XCTAssertEqual(scene(7, 12).season, .monsoon)
        XCTAssertEqual(scene(9, 12).season, .monsoon)
        XCTAssertEqual(scene(10, 12).season, .winter)
        XCTAssertEqual(scene(1, 12).season, .winter)
    }

    func testArtworkComposesRequestedSize() {
        let p = CarProfile(make: "Jeep", model: "Meridian", colour: "Galaxy Blue", roof: "Body", wheels: "", nickname: "", renderId: nil, ownerName: "A")
        let img = ArtworkComposer.compose(profile: p, line1: "Hi", line2: "A", side: 64, scene: ArtworkScene(timeOfDay: .dusk, season: .monsoon))
        XCTAssertEqual(img.size.width, 64)
        XCTAssertEqual(img.size.height, 64)
    }
}

final class ProfileTests: IsolatedStoreTestCase {
    func testSwitchingChangesActiveAndFeedsStore() throws {
        let a = profile(name: "Mohit", model: "Meridian")
        let b = profile(name: "Papa", model: "Fortuner")
        try SharedStore.saveProfile(a)
        try SharedStore.saveProfile(b)
        XCTAssertEqual(SharedStore.loadProfile()?.id, b.id)
        var book = SharedStore.loadBook()
        XCTAssertEqual(book.profiles.count, 2)
        XCTAssertTrue(book.switchTo(a.id))
        try SharedStore.saveBook(book)
        XCTAssertEqual(SharedStore.loadProfile()?.ownerName, "Mohit")
        XCTAssertFalse(book.switchTo("nope"))
    }

    func testUpdateActiveOnlyTouchesActive() {
        var book = ProfileBook()
        let a = profile(name: "A"), b = profile(name: "B")
        book.upsert(a)
        book.upsert(b)
        book.switchTo(a.id)
        book.updateActive { $0.widgetStyle = .stats }
        XCTAssertEqual(book.profiles.first(where: { $0.id == a.id })?.widgetStyle, .stats)
        XCTAssertEqual(book.profiles.first(where: { $0.id == b.id })?.widgetStyle, .carLarge)
    }

    func testRemoveActiveFallsBack() {
        var book = ProfileBook()
        let a = profile(name: "A"), b = profile(name: "B")
        book.upsert(a)
        book.upsert(b)
        book.remove(b.id)
        XCTAssertEqual(book.active?.id, a.id)
    }

    func testProfileSettingsSurviveEncoding() throws {
        var p = profile()
        p.ritual.theme = .minimal
        p.ritual.setDelay(3)
        p.ritual.voiceOn = false
        p.briefingItems = [.streak]
        p.greetingIndex = 1
        p.widgetStyle = .minimal
        p.lovedOne = LovedOne(label: "Papa", fileName: "x.m4a", enabled: true)
        try SharedStore.saveProfile(p)
        XCTAssertEqual(SharedStore.loadProfile(), p)
    }

    func testMetricEventNames() {
        XCTAssertEqual(Metrics.Event.profileSwitched.rawValue, "profile_switched")
        XCTAssertEqual(Metrics.Event.lovedOnePlayed.rawValue, "loved_one_played")
    }
}

final class RitualTests: XCTestCase {
    func testDelayIsClampedToZeroToFive() {
        var r = Ritual()
        r.setDelay(9)
        XCTAssertEqual(r.delaySeconds, 5)
        r.setDelay(-2)
        XCTAssertEqual(r.delaySeconds, 0)
        r.setDelay(3)
        XCTAssertEqual(r.delaySeconds, 3)
    }

    func testPlanVariants() {
        var r = Ritual()
        r.theme = .warm
        r.setDelay(2)
        XCTAssertEqual(RitualPlan.steps(ritual: r, lovedOneAvailable: false), [.chime(.warm), .pause(2), .briefing])
        XCTAssertEqual(RitualPlan.steps(ritual: r, lovedOneAvailable: true), [.chime(.warm), .lovedOne, .pause(2), .briefing])
        r.setDelay(0)
        XCTAssertEqual(RitualPlan.steps(ritual: r, lovedOneAvailable: false), [.chime(.warm), .briefing])
        r.voiceOn = false
        XCTAssertEqual(RitualPlan.steps(ritual: r, lovedOneAvailable: true), [.chime(.warm), .lovedOne])
    }

    func testLovedOneLimitIsFifteenSeconds() {
        XCTAssertEqual(LovedOne.maxSeconds, 15)
    }

    func testShortcutSetupTracking() {
        var s = ShortcutSetup()
        XCTAssertFalse(s.isComplete)
        for i in ShortcutSetup.steps.indices { XCTAssertTrue(s.toggle(i)) }
        XCTAssertTrue(s.isComplete)
        XCTAssertFalse(s.toggle(0))
        XCTAssertFalse(s.isComplete)
        XCTAssertFalse(s.toggle(99))
        XCTAssertEqual(ShortcutSetup.shortcutsURL.scheme, "shortcuts")
    }
}

final class WidgetSnapshotTests: IsolatedStoreTestCase {
    func testNextUpWinsAndStylePassesThrough() {
        var p = profile(colour: "Galaxy Blue")
        p.widgetStyle = .stats
        let now = date(2026, 11, 10, 18)
        let next = SharedStore.NextUp(title: "Clinic 9:30", detail: "32 min", updated: now)
        let drives = (0..<3).map { drive(date(2026, 11, 10 - $0, 8), km: 10) }
        let s = WidgetSnapshot.make(profile: p, nextUp: next, drives: drives, now: now, calendar: cal)
        XCTAssertEqual(s.title, "Clinic 9:30")
        XCTAssertEqual(s.detail, "32 min")
        XCTAssertEqual(s.style, .stats)
        XCTAssertEqual(s.accentHex, "#5B9BD5")
        XCTAssertEqual(s.streak, 3)
        XCTAssertEqual(s.totalKm, 30)
        XCTAssertEqual(s.carName, "Meridian")
    }

    func testFallsBackToUsualStopThenReady() {
        let p = profile()
        let now = date(2026, 11, 23, 9, 10)
        let drives = (0..<3).map { drive(date(2026, 11, 2 + 7 * $0, 9, 0)) }
        let s = WidgetSnapshot.make(profile: p, nextUp: nil, drives: drives, now: now, calendar: cal)
        XCTAssertEqual(s.title, "Clinic")
        XCTAssertEqual(s.detail, "30 min")
        let none = WidgetSnapshot.make(profile: p, nextUp: nil, drives: [], now: now, calendar: cal)
        XCTAssertEqual(none.title, "Ready")
        XCTAssertEqual(WidgetSnapshot.make(profile: nil, nextUp: nil, drives: [], now: now), .empty)
    }

    func testLoadsFromAppGroupData() throws {
        var p = profile()
        p.widgetStyle = .minimal
        try SharedStore.saveProfile(p)
        try SharedStore.saveNextUp(SharedStore.NextUp(title: "Gym", detail: "18 min", updated: Date()))
        let s = WidgetSnapshot.load()
        XCTAssertEqual(s.title, "Gym")
        XCTAssertEqual(s.style, .minimal)
    }

    func testRefreshIsFifteenMinutes() {
        let now = Date()
        XCTAssertEqual(WidgetSnapshot.refreshDate(after: now).timeIntervalSince(now), 900, accuracy: 0.1)
    }
}

final class BundleTests: XCTestCase {
    func testAllTwelveWelcomeClipsResolve() {
        let hours: [DayPeriod: Int] = [.morning: 8, .afternoon: 14, .evening: 18, .night: 23]
        var found = 0
        for theme in SoundTheme.allCases {
            for period in DayPeriod.allCases {
                let url = SoundLibrary.url(for: theme, hour: hours[period]!)
                XCTAssertNotNil(url, "\(theme.rawValue)-\(period.rawValue)")
                if let url {
                    found += 1
                    XCTAssertGreaterThan((try? Data(contentsOf: url).count) ?? 0, 1000)
                }
            }
        }
        XCTAssertEqual(found, 12)
    }

    func testEveryBundledCarImageDecodesAndMatchesCatalogue() throws {
        let catalog = CarCatalog.load()
        XCTAssertFalse(catalog.models.isEmpty, "catalogue is bundled")
        let dir = try XCTUnwrap(Bundle.main.url(forResource: "cars", withExtension: nil), "cars folder is bundled")
        let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil).filter { $0.pathExtension == "jpg" }
        XCTAssertGreaterThan(files.count, 0)
        let known = Set(catalog.models.flatMap { m in m.colours.map { "\(m.slug)--\($0.id)" } })
        for f in files {
            XCTAssertNotNil(UIImage(contentsOfFile: f.path), f.lastPathComponent)
            XCTAssertTrue(known.contains(f.deletingPathExtension().lastPathComponent), "orphan render \(f.lastPathComponent)")
        }
    }

    func testWidgetExtensionIsEmbedded() throws {
        let plugins = try XCTUnwrap(Bundle.main.builtInPlugInsURL)
        let names = try FileManager.default.contentsOfDirectory(atPath: plugins.path)
        XCTAssertTrue(names.contains("MyDriveWidget.appex"), "plug-ins: \(names)")
    }

    func testMicrophoneUsageDescriptionPresent() {
        let text = Bundle.main.object(forInfoDictionaryKey: "NSMicrophoneUsageDescription") as? String
        XCTAssertFalse((text ?? "").isEmpty)
    }
}
