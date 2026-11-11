import AVFoundation
import CarPlay
import XCTest
@testable import MyDrive

// MARK: - Briefing text vs what the clip already said

final class ClipCoverageBriefingTests: IsolatedStoreTestCase {
    private let greetings = GreetingBook.fallback
    private let hourFor: [DayPeriod: Int] = [.morning: 9, .afternoon: 14, .evening: 18, .night: 23]

    private func text(_ theme: SoundTheme, _ period: DayPeriod, name: String = "Mohit", spoken: String? = nil) -> String {
        var p = profile(name: name)
        p.spokenName = spoken
        let now = date(2026, 11, 10, hourFor[period]!)
        return BriefingBuilder.compose(profile: p, nextUp: nil, drives: [], greetings: greetings, now: now,
                                       clip: ClipCoverage.of(theme: theme, period: period), calendar: cal)
    }

    func testEveryThemeAndPeriodNeverRepeatsWhatTheClipSaid() {
        for theme in SoundTheme.allCases {
            for period in DayPeriod.allCases {
                let cov = ClipCoverage.of(theme: theme, period: period)
                let t = text(theme, period)
                let tag = "\(theme.rawValue)-\(period.rawValue): \(t)"
                XCTAssertTrue(t.hasPrefix("Mohit"), tag)                       // starts at the driver's name
                for hello in ["Good morning", "Good afternoon", "Good evening", "Hello", "Good night"] {
                    XCTAssertFalse(t.contains(hello), tag)
                }
                if cov.ready { XCTAssertFalse(t.lowercased().contains("ready"), tag) }
                else { XCTAssertTrue(t.contains("is ready."), tag) }
                if cov.safeClosing { XCTAssertFalse(t.contains("Have a good drive"), tag) }
                else { XCTAssertTrue(t.hasSuffix("Have a good drive."), tag) }
                XCTAssertTrue(t.contains("Meridian"), tag)
            }
        }
    }

    func testCoverageFlagsMatchTheActualClipTexts() {
        for theme in SoundTheme.allCases {
            for period in DayPeriod.allCases {
                let c = ClipCoverage.of(theme: theme, period: period)
                let l = c.text.lowercased()
                XCTAssertFalse(c.text.isEmpty)
                XCTAssertEqual(c.greeting, l.contains("good morning") || l.contains("good afternoon") || l.contains("good evening")
                                            || l.contains("good night") || l.contains("hello"), "\(theme) \(period)")
                XCTAssertEqual(c.ready, l.contains("ready"), "\(theme) \(period)")
                XCTAssertEqual(c.safeClosing, l.contains("drive safe") || l.contains("good drive") || l.contains("home safely"),
                               "\(theme) \(period)")
            }
        }
    }

    func testBriefingOnlyPathKeepsFullGreeting() {
        let now = date(2026, 11, 10, 18)
        let t = BriefingBuilder.compose(profile: profile(), nextUp: nil, drives: [], greetings: greetings, now: now, clip: .none, calendar: cal)
        XCTAssertEqual(t, "Good evening, Mohit. Your Meridian is ready. Have a good drive.")
    }

    func testSpokenNameReplacesOwnerNameInTheVoiceOnly() {
        XCTAssertTrue(text(.jarvis, .evening, spoken: "Moe-hit").hasPrefix("Moe-hit, welcome back"))
        XCTAssertFalse(text(.jarvis, .evening, spoken: "Moe-hit").contains("Mohit"))
        XCTAssertTrue(text(.jarvis, .evening, spoken: "  ").hasPrefix("Mohit,"))
        XCTAssertTrue(text(.jarvis, .evening, spoken: nil).hasPrefix("Mohit,"))
        var p = profile(); p.spokenName = "Moe-hit"
        let full = BriefingBuilder.compose(profile: p, nextUp: nil, drives: [], greetings: greetings, now: date(2026, 11, 10, 18), calendar: cal)
        XCTAssertTrue(full.hasPrefix("Good evening, Moe-hit."))
    }

    func testUsualStopAndStreakStillSpokenAfterAClip() {
        let now = date(2026, 11, 23, 9, 30)
        let drives = (0..<3).map { drive(date(2026, 11, 2 + 7 * $0, 9, 0)) }
        let t = BriefingBuilder.compose(profile: profile(), nextUp: nil, drives: drives, greetings: greetings, now: now,
                                        clip: ClipCoverage.of(theme: .jarvis, period: .morning), calendar: cal)
        XCTAssertTrue(t.contains("Clinic at 9:30"), t)
    }

    func testSpokenNameRoundTripsThroughTheStore() throws {
        var p = profile()
        p.spokenName = "Moe-hit"
        try SharedStore.saveProfile(p)
        XCTAssertEqual(SharedStore.loadProfile()?.spokenName, "Moe-hit")
        XCTAssertEqual(SharedStore.loadProfile()?.nameForSpeech, "Moe-hit")
        XCTAssertEqual(SharedStore.loadProfile()?.ownerName, "Mohit")
        // A profile saved before the field existed still loads.
        let old = Data("""
        {"profiles":[{"make":"Jeep","model":"Meridian","colour":"White","roof":"Body","wheels":"","nickname":"","ownerName":"Mohit","id":"a"}],"activeId":"a"}
        """.utf8)
        let book = try JSONDecoder().decode(ProfileBook.self, from: old)
        XCTAssertNil(book.active?.spokenName)
        XCTAssertEqual(book.active?.nameForSpeech, "Mohit")
    }

    func testDefaultPauseIsZeroAndOldStoredDefaultIsDropped() throws {
        XCTAssertEqual(Ritual().delaySeconds, 0)
        let old = Data(#"{"theme":"jarvis","delaySeconds":1,"voiceOn":true}"#.utf8)
        XCTAssertEqual(try JSONDecoder().decode(Ritual.self, from: old).delaySeconds, 0)
        var r = Ritual(); r.setDelay(3)
        let again = try JSONDecoder().decode(Ritual.self, from: try JSONEncoder().encode(r))
        XCTAssertEqual(again.delaySeconds, 3)
    }
}

// MARK: - Normaliser

final class SpeechTextTests: XCTestCase {
    func testTimes() {
        XCTAssertEqual(SpeechText.normalise("Clinic at 9:30"), "Clinic at nine thirty")
        XCTAssertEqual(SpeechText.normalise("at 9:05"), "at nine oh five")
        XCTAssertEqual(SpeechText.normalise("at 12:00"), "at twelve o'clock")
        XCTAssertEqual(SpeechText.normalise("at 18:45"), "at six forty five")
        XCTAssertEqual(SpeechText.normalise("at 9:30 pm"), "at nine thirty P M")
    }

    func testUnitsAndOrdinals() {
        XCTAssertEqual(SpeechText.normalise("32 min"), "32 minutes")
        XCTAssertEqual(SpeechText.normalise("1 min"), "1 minute")
        XCTAssertEqual(SpeechText.normalise("14.2 km total"), "14.2 kilometres total")
        XCTAssertEqual(SpeechText.normalise("on the 3rd and 21st"), "on the third and twenty first")
    }

    func testDashesBecomePauses() {
        XCTAssertEqual(SpeechText.normalise("Clinic at 9:30 — 32 min."), "Clinic at nine thirty, 32 minutes.")
        XCTAssertEqual(SpeechText.normalise("Home - Office"), "Home, Office")
        XCTAssertFalse(SpeechText.normalise("Moe-hit, Mercedes-Benz, Scorpio-N").contains("-"))
    }

    func testCarNameRespellings() {
        XCTAssertEqual(SpeechText.normalise("XUV700"), "X U V seven hundred")
        XCTAssertEqual(SpeechText.normalise("Thar Roxx"), "Thar Rocks")
        XCTAssertEqual(SpeechText.normalise("Maruti Suzuki Dzire"), "Maruti Suzuki Desire")
        XCTAssertEqual(SpeechText.normalise("BMW X1"), "B M W X one")
        XCTAssertEqual(SpeechText.normalise("Hyryder"), "Hi rider")
    }

    func testIPAOverridesAreAttachedToTheRightWords() {
        let text = SpeechText.normalise("Mohit, your Jeep Meridian is ready.")
        let (utt, hits) = SpeechText.utterance(for: text)
        XCTAssertEqual(hits.map(\.word), ["Meridian"])
        let key = NSAttributedString.Key(rawValue: AVSpeechSynthesisIPANotationAttribute)
        let attr = utt.attributedSpeechString
        XCTAssertEqual(attr.string, text)
        var range = NSRange()
        XCTAssertEqual(attr.attribute(key, at: hits[0].range.location, effectiveRange: &range) as? String, hits[0].ipa)
        XCTAssertEqual(range, hits[0].range)
        XCTAssertNil(attr.attribute(key, at: 0, effectiveRange: nil))
    }

    func testPlainTextHasNoIPA() {
        XCTAssertTrue(SpeechText.ipaHits(in: "Good evening, Mohit.").isEmpty)
    }

    func testEveryCatalogueCarSpeaksCleanly() {
        let models = CarCatalog.load().models
        XCTAssertGreaterThan(models.count, 30)
        for m in models {
            let s = SpeechText.normalise("Your \(m.make) \(m.model) is ready.")
            XCTAssertFalse(s.contains("-"), s)
            XCTAssertFalse(s.contains("  "), s)
            XCTAssertTrue(s.hasPrefix("Your "), s)
            XCTAssertTrue(s.hasSuffix("is ready."), s)
        }
    }

    func testSpokenTimeWords() {
        XCTAssertEqual(SpeechText.words(0), "zero")
        XCTAssertEqual(SpeechText.words(19), "nineteen")
        XCTAssertEqual(SpeechText.words(40), "forty")
        XCTAssertEqual(SpeechText.words(59), "fifty nine")
    }
}

// MARK: - Voice choice

final class VoiceChooserTests: XCTestCase {
    private func v(_ name: String, _ lang: String, _ q: Int, id: String? = nil) -> VoiceInfo {
        VoiceInfo(identifier: id ?? "com.apple.voice.compact.\(lang).\(name)", name: name, language: lang, quality: q)
    }

    func testNoveltyAndRoboticVoicesAreExcluded() {
        let voices = [
            v("Fred", "en-US", 1, id: "com.apple.speech.synthesis.voice.Fred"),
            v("Zarvox", "en-US", 1, id: "com.apple.speech.synthesis.voice.Zarvox"),
            v("Rocko", "en-US", 1, id: "com.apple.eloquence.en-US.Rocko"),
            v("Bells", "en-US", 3), v("Samantha", "en-US", 1),
        ]
        XCTAssertEqual(VoiceChooser.rank(voices).map(\.name), ["Samantha"])
    }

    func testQualityBeatsLanguageAndName() {
        let voices = [v("Daniel", "en-GB", 1), v("Rishi", "en-IN", 1), v("Samantha", "en-US", 2), v("Ava", "en-US", 3)]
        XCTAssertEqual(VoiceChooser.rank(voices).map(\.name), ["Ava", "Samantha", "Rishi", "Daniel"])
    }

    func testEstablishedMaleVoicesThenLanguagePreference() {
        let voices = [v("Kate", "en-GB", 1), v("Veena", "en-IN", 1), v("Daniel", "en-GB", 1), v("Karen", "en-AU", 1), v("Zoe", "en-US", 1)]
        let r = VoiceChooser.rank(voices).map(\.name)
        XCTAssertEqual(r.first, "Daniel")
        XCTAssertEqual(Array(r.dropFirst()), ["Veena", "Kate", "Karen", "Zoe"])
    }

    func testNonEnglishIsIgnoredAndEmptyIsNil() {
        XCTAssertNil(VoiceChooser.choose(from: [v("Amelie", "fr-CA", 3)]))
        XCTAssertNil(VoiceChooser.choose(from: []))
    }

    func testHintOnlyForDefaultQuality() {
        XCTAssertNotNil(VoiceChooser.hint(for: v("Daniel", "en-GB", 1)))
        XCTAssertNotNil(VoiceChooser.hint(for: nil))
        XCTAssertNil(VoiceChooser.hint(for: v("Daniel", "en-GB", 2)))
        XCTAssertTrue(VoiceChooser.upgradeHint.contains("Spoken Content"))
    }

    func testSystemVoicesAreEnumerated() {
        let r = VoiceChooser.current()
        XCTAssertFalse(r.ranked.contains(where: VoiceChooser.isNovelty))
        for x in r.ranked { XCTAssertTrue(x.language.lowercased().hasPrefix("en")) }
    }
}

// MARK: - Diagnostics and the engine's duplicate / interrupt handling

@MainActor
final class DiagnosticsAndEngineTests: IsolatedStoreTestCase {
    func testDiagnosticsWritesJSONLines() {
        Diagnostics.shared.log("unit_test_stage", ["a": 1, "b": "x"])
        Diagnostics.shared.log("unit_test_stage_2")
        let rows = Diagnostics.shared.rows()
        XCTAssertEqual(rows.map { $0["stage"] as? String }, ["unit_test_stage", "unit_test_stage_2"])
        XCTAssertEqual(rows[0]["a"] as? Int, 1)
        XCTAssertNotNil(rows[0]["ts"])
        XCTAssertNotNil(rows[0]["up_ms"])
        XCTAssertEqual(Diagnostics.shared.tail(1).split(separator: "\n").count, 1)
    }

    func testSameSurfaceTwiceIsIgnoredAndDifferentSurfaceInterrupts() throws {
        try SharedStore.saveProfile(profile())
        let engine = DriveAudioEngine.shared
        engine.stop()
        Diagnostics.shared.clear()
        engine.playWelcomeSequence(surface: "unit-a")
        engine.playWelcomeSequence(surface: "unit-a")          // duplicate: ignored
        engine.playWelcomeSequence(surface: "unit-b")          // other surface: interrupts the first
        let stages = Diagnostics.shared.rows().compactMap { $0["stage"] as? String }
        XCTAssertEqual(stages.filter { $0 == "sequence_started" }.count, 2, "\(stages)")
        XCTAssertEqual(stages.filter { $0 == "duplicate_ignored" }.count, 1, "\(stages)")
        XCTAssertEqual(stages.filter { $0 == "sequence_interrupted" }.count, 1, "\(stages)")
        engine.stop()
        XCTAssertEqual(Diagnostics.shared.rows().compactMap { $0["stage"] as? String }.filter { $0 == "sequence_interrupted" }.count, 2)
    }
}

// MARK: - Car screen templates (via the mockable seam)

final class CarPlayTemplatesTests: IsolatedStoreTestCase {
    private func items(_ t: CPListTemplate) -> [[CPListItem]] {
        t.sections.map { $0.items.compactMap { $0 as? CPListItem } }
    }

    func testTodayTabItemsAndActions() {
        var calls: [(SoundTheme?, Bool)] = []
        let actions = CarPlayTemplates.Actions(play: { calls.append(($0, $1)) })
        var p = profile(); p.ritual.theme = .warm
        let t = CarPlayTemplates.today(profile: p, nextUp: SharedStore.NextUp(title: "Gym", detail: "18 min", updated: Date()),
                                       artwork: { _ in nil }, actions: actions)
        let list = items(t)[0]
        XCTAssertEqual(list.map(\.text), ["Welcome theme", "Today's briefing"])
        XCTAssertEqual(list[0].detailText, "Meridian · Warm")
        XCTAssertEqual(list[1].detailText, "Gym")
        list[0].handler?(list[0]) {}
        list[1].handler?(list[1]) {}
        XCTAssertEqual(calls.count, 2)
        XCTAssertNil(calls[0].0); XCTAssertFalse(calls[0].1)
        XCTAssertTrue(calls[1].1)
    }

    func testLibraryListsEveryThemeAndPlaysIt() {
        var played: [SoundTheme?] = []
        let t = CarPlayTemplates.library(actions: .init(play: { th, _ in played.append(th) }))
        let list = items(t)[0]
        XCTAssertEqual(list.map(\.text), SoundTheme.allCases.map(\.title))
        list.forEach { $0.handler?($0) {} }
        XCTAssertEqual(played.compactMap { $0 }, SoundTheme.allCases)
    }

    func testDrivesTabEmptyAndFilled() {
        let now = date(2026, 11, 23, 9, 30)
        let empty = CarPlayTemplates.drivesTab([], now: now, calendar: cal)
        XCTAssertEqual(items(empty)[0].map(\.text), ["No drives yet"])

        let drives = (0..<3).map { drive(date(2026, 11, 2 + 7 * $0, 9, 0), km: 10) }
        let t = CarPlayTemplates.drivesTab(drives, now: now, calendar: cal)
        let sections = items(t)
        XCTAssertEqual(sections[0].map(\.text), ["Streak", "Total distance", "Favourite route"])
        XCTAssertEqual(sections[0][1].detailText, "30 km")
        XCTAssertEqual(sections[0][2].detailText, "Home to Clinic · 3 drives")
        XCTAssertEqual(t.sections.map { $0.header }.compactMap { $0 }, ["Your drives", "Usual stops", "Recent"])
        XCTAssertEqual(sections[1][0].text, "Clinic")
        XCTAssertEqual(sections[2].count, 3)
    }

    func testRootHasThreeTabsAndAtMostFourAllowed() {
        let root = CarPlayTemplates.root(profile: profile(), nextUp: nil, drives: [], now: Date(), artwork: { _ in nil },
                                         actions: .init(play: { _, _ in }))
        XCTAssertEqual(root.templates.compactMap { ($0 as? CPListTemplate)?.title }, ["Today", "Library", "Drives"])
        XCTAssertLessThanOrEqual(root.templates.count, 4)
    }
}

// MARK: - Widget per style

final class WidgetStyleTests: IsolatedStoreTestCase {
    func testEveryStyleReachesTheSnapshot() {
        for style in WidgetStyle.allCases {
            var p = profile(colour: "Galaxy Blue")
            p.widgetStyle = style
            let s = WidgetSnapshot.make(profile: p, nextUp: nil, drives: [drive(date(2026, 11, 10, 8))], now: date(2026, 11, 10, 18), calendar: cal)
            XCTAssertEqual(s.style, style)
            XCTAssertEqual(s.accentHex, "#5B9BD5")
            XCTAssertEqual(s.streak, 1)
        }
    }

    func testSnapshotFollowsTheActiveProfile() throws {
        var a = profile(name: "Mohit", colour: "Galaxy Blue"); a.widgetStyle = .stats
        var b = profile(name: "Asha", colour: "Velvet Red", model: "Creta"); b.widgetStyle = .minimal
        try SharedStore.saveProfile(a)
        try SharedStore.saveProfile(b)
        XCTAssertEqual(WidgetSnapshot.load().carName, "Creta")
        XCTAssertEqual(WidgetSnapshot.load().style, .minimal)
        var book = SharedStore.loadBook()
        book.switchTo(a.id)
        try SharedStore.saveBook(book)
        XCTAssertEqual(WidgetSnapshot.load().carName, "Meridian")
        XCTAssertEqual(WidgetSnapshot.load().style, .stats)
    }
}
