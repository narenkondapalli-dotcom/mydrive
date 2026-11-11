import XCTest

/// End-to-end UI tests on the simulator. The app runs in deterministic mode (see UITestSupport): data in /tmp/mydrive-uitest,
/// optional seeded profile, pinned hour. Every step takes a screenshot attachment. The app writes diagnostics.jsonl into the
/// same folder, which the tests read to check stage order, timings and the spoken text.
final class MyDriveUITests: XCTestCase {
    typealias Row = [String: Any]
    var app: XCUIApplication!
    private let folder = "/tmp/mydrive-uitest"

    override func setUp() {
        continueAfterFailure = false
    }

    /// Keeps each test's diagnostics.jsonl and metrics.jsonl for the CI artifacts (the app wipes its folder on the next reset launch).
    override func tearDown() {
        let dest = URL(fileURLWithPath: "/tmp/mydrive-ci-out/uitest/\(testLabel(self))")
        try? FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
        for f in ["diagnostics.jsonl", "metrics.jsonl"] {
            try? FileManager.default.copyItem(atPath: "\(folder)/\(f)", toPath: dest.appendingPathComponent(f).path)
        }
        super.tearDown()
    }

    // MARK: Launch and helpers

    func launch(reset: Bool = true, seed: Bool = true, hour: Int? = nil, colour: String? = nil) {
        app = XCUIApplication()
        var args = ["-uitest"]
        if reset { args.append("-uitest-reset") }
        if seed { args.append("-uitest-seed") }
        if let hour { args += ["-uitest-hour", "\(hour)"] }
        if let colour { args += ["-uitest-colour", colour] }
        app.launchArguments = args
        app.launch()
    }

    func relaunch(hour: Int? = nil) {
        app.terminate()
        launch(reset: false, seed: false, hour: hour)
    }

    func shot(_ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = "\(testLabel(self))-\(name)"
        a.lifetime = .keepAlways
        add(a)
    }

    private func testLabel(_ t: XCTestCase) -> String {
        t.name.replacingOccurrences(of: "-[MyDriveUITests ", with: "").replacingOccurrences(of: "]", with: "")
    }

    func reveal(_ e: XCUIElement) {
        var n = 0
        while !(e.exists && e.isHittable) && n < 8 { app.swipeUp(); n += 1 }
        n = 0
        while !(e.exists && e.isHittable) && n < 14 { app.swipeDown(); n += 1 }
    }

    func tap(_ e: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(e.waitForExistence(timeout: 10), "missing \(e)", file: file, line: line)
        reveal(e)
        e.tap()
    }

    func openLink(_ label: String) { tap(app.buttons[label]) }
    func openRitual() { openLink("Your ritual and look") }
    func openDebug() { openLink("Debug & measurements") }
    func back() { app.navigationBars.buttons.element(boundBy: 0).tap() }

    func rows() -> [Row] {
        guard let text = try? String(contentsOfFile: "\(folder)/diagnostics.jsonl", encoding: .utf8) else { return [] }
        return text.split(separator: "\n").compactMap { (try? JSONSerialization.jsonObject(with: Data($0.utf8))) as? Row }
    }

    func stages(_ r: [Row] = []) -> [String] { (r.isEmpty ? rows() : r).compactMap { $0["stage"] as? String } }
    func count(_ stage: String) -> Int { stages().filter { $0 == stage }.count }

    /// Waits until `stage` has been logged more than `before` times.
    @discardableResult
    func waitFor(_ stage: String, moreThan before: Int, timeout: TimeInterval = 70) -> Bool {
        let end = Date().addingTimeInterval(timeout)
        while Date() < end {
            if count(stage) > before { return true }
            Thread.sleep(forTimeInterval: 0.25)
        }
        return false
    }

    /// Rows of the most recent sequence only.
    func lastSequence() -> [Row] {
        let all = rows()
        guard let i = all.lastIndex(where: { $0["stage"] as? String == "sequence_started" }) else { return [] }
        return Array(all[i...])
    }

    func row(_ stage: String, in seq: [Row]) -> Row? { seq.first { $0["stage"] as? String == stage } }

    func metricsEvents() -> [String] {
        guard let text = try? String(contentsOfFile: "\(folder)/metrics.jsonl", encoding: .utf8) else { return [] }
        return text.split(separator: "\n").compactMap {
            ((try? JSONSerialization.jsonObject(with: Data($0.utf8))) as? Row)?["event"] as? String
        }
    }

    /// Starts something that plays and waits for it to finish.
    func playAndWait(_ button: XCUIElement) -> [Row] {
        let before = count("sequence_finished")
        tap(button)
        XCTAssertTrue(waitFor("sequence_finished", moreThan: before), "sequence did not finish; stages: \(stages())")
        return lastSequence()
    }

    func normalisedText(_ seq: [Row]) -> String { row("utterance", in: seq)?["normalised"] as? String ?? "" }
    func rawText(_ seq: [Row]) -> String { row("utterance", in: seq)?["raw"] as? String ?? "" }

    func setSwitch(_ id: String, on: Bool) {
        let s = app.switches[id]
        tap(s)  // tap once to read state change below
        // tap() above toggled it; toggle back if it is not what we want.
        let isOn = (s.value as? String) == "1"
        if isOn != on { s.tap() }
    }

    func switchIsOn(_ id: String) -> Bool { (app.switches[id].value as? String) == "1" }

    // MARK: 1. Onboarding

    func testOnboardingFullFlowAndAdjust() {
        launch(seed: false)
        XCTAssertTrue(app.staticTexts["Which car do you drive?"].waitForExistence(timeout: 15))
        shot("01-step1-empty")
        let next = app.buttons["onboarding-next"]
        XCTAssertFalse(next.isEnabled, "Next must be disabled until a car is picked")

        let search = app.textFields["car-search"]
        search.tap(); search.typeText("Jeep")
        shot("02-search-jeep")
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Jeep Meridian'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        shot("03-meridian-selected")
        XCTAssertTrue(next.isEnabled)
        next.tap()

        XCTAssertTrue(app.staticTexts["What colour is it?"].waitForExistence(timeout: 5))
        let pearl = app.staticTexts["Pearl White"].firstMatch
        XCTAssertTrue(pearl.waitForExistence(timeout: 5))
        pearl.tap()
        shot("04-colour-pearl-white")
        next.tap()

        XCTAssertTrue(app.staticTexts["Meet your Meridian"].waitForExistence(timeout: 5))
        shot("05-meet-your-car")
        let name = app.textFields["owner-name"]; name.tap(); name.typeText("Mohit")
        let nick = app.textFields["nickname"]; nick.tap(); nick.typeText("Meri")
        dismissKeyboard()
        shot("06-names-typed")

        // Back / adjust: returns to the colour step and keeps what was typed.
        tap(app.buttons["adjust"])
        XCTAssertTrue(app.staticTexts["What colour is it?"].waitForExistence(timeout: 5))
        shot("07-adjust-back-to-colour")
        next.tap()
        XCTAssertEqual(app.textFields["owner-name"].value as? String, "Mohit")
        tap(app.buttons["onboarding-next"])   // "Looks right"

        XCTAssertTrue(app.buttons["test-welcome"].waitForExistence(timeout: 10), "Home did not appear after onboarding")
        XCTAssertEqual(app.staticTexts["home-name"].label, "Mohit")
        shot("08-home-after-onboarding")

        // Documented in SPEC step 1 but not built on iOS: record the state honestly.
        let cant = app.buttons["Can't find it?"]
        NSLog("FINDING cant-find-it-path present=\(cant.exists)")
        XCTAssertTrue(true)

        relaunch()
        XCTAssertTrue(app.buttons["test-welcome"].waitForExistence(timeout: 10), "profile did not survive relaunch")
        XCTAssertEqual(app.staticTexts["home-name"].label, "Mohit")
        shot("09-relaunch-still-home")
    }

    func dismissKeyboard() {
        for k in ["Return", "return", "Done", "done"] where app.keyboards.buttons[k].exists {
            app.keyboards.buttons[k].tap(); return
        }
    }

    // MARK: 2. Home

    func testHomeContents() {
        launch(hour: 18)
        XCTAssertTrue(app.buttons["test-welcome"].waitForExistence(timeout: 15))
        XCTAssertEqual(app.staticTexts["home-name"].label, "Mohit")
        XCTAssertTrue(app.staticTexts["home-greeting"].label.lowercased().contains("evening"), app.staticTexts["home-greeting"].label)
        XCTAssertTrue(app.buttons["Your ritual and look"].exists)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS 'shortcut'")).firstMatch.exists)
        XCTAssertTrue(app.buttons["Debug & measurements"].exists)
        XCTAssertTrue(app.buttons["add-car"].exists)
        NSLog("FINDING voice-hint-visible=\(app.staticTexts["voice-hint"].exists)")
        shot("home")
    }

    // MARK: 3. Test welcome: stages, timings, gap, text

    func testWelcomeSequenceStagesTimingsAndText() {
        launch(hour: 18)
        let before = count("sequence_finished")
        tap(app.buttons["test-welcome"])
        shot("playing-start")
        XCTAssertTrue(waitFor("sequence_finished", moreThan: before), "stages: \(stages())")
        shot("playing-end")
        let seq = lastSequence()
        let st = stages(seq)

        func idx(_ s: String) -> Int { st.firstIndex(of: s) ?? -1 }
        for s in ["sequence_started", "utterance", "session_activated", "audio_ready", "clip_started", "speech_rendered",
                  "speech_started", "speech_finished", "sequence_finished", "session_deactivated"] {
            XCTAssertGreaterThanOrEqual(idx(s), 0, "missing stage \(s) in \(st)")
        }
        XCTAssertLessThan(idx("sequence_started"), idx("clip_started"))
        XCTAssertLessThan(idx("clip_started"), idx("speech_started"))
        XCTAssertLessThan(idx("speech_started"), idx("speech_finished"))
        XCTAssertLessThan(idx("speech_finished"), idx("sequence_finished"))
        XCTAssertLessThan(idx("sequence_finished"), idx("session_deactivated"))

        // Metrics events in order (the file is written asynchronously).
        Thread.sleep(forTimeInterval: 0.8)
        let m = metricsEvents()
        let order = ["welcome_started", "welcome_finished", "briefing_started", "briefing_finished", "handoff_music"]
        var last = -1
        for e in order {
            let i = m.lastIndex(of: e) ?? -1
            XCTAssertGreaterThan(i, last, "metrics order wrong at \(e): \(m)")
            last = i
        }

        // Continuity: the speech is queued right behind the clip.
        if let sched = row("speech_scheduled", in: seq) {
            let gap = (sched["gap_ms"] as? Int) ?? 9999
            NSLog("FINDING gap_ms=\(gap) mode=\(sched["mode"] ?? "?") lateness_ms=\(sched["lateness_ms"] ?? "?")")
            XCTAssertLessThanOrEqual(gap, 250, "gap between clip end and speech start")
        } else {
            XCTFail("speech was not scheduled: \(row("speech_fallback", in: seq) ?? [:])")
        }
        let ready = row("audio_ready", in: seq)
        NSLog("FINDING audio_ready=\(ready ?? [:])  engine_unavailable=\(row("engine_unavailable", in: seq) != nil)")

        // Text: starts at the name and does not repeat the clip ("Good evening, sir. All systems online and ready.").
        let text = normalisedText(seq)
        XCTAssertTrue(text.hasPrefix("Mohit"), text)
        XCTAssertFalse(text.contains("Good evening"), text)
        XCTAssertFalse(text.lowercased().contains("ready"), text)
        XCTAssertEqual(row("clip_started", in: seq)?["file"] as? String, "jarvis-evening.mp3")
        XCTAssertTrue(app.buttons["test-welcome"].label.contains("Test welcome"), "button should return to idle")
    }

    // MARK: 4. Every theme x period plays the right clip

    func testEveryThemeAndPeriodPlaysItsClip() {
        launch(hour: 8)
        openRitual()
        setSwitch("voice-toggle", on: false)
        shot("ritual-voice-off")
        back()
        let periods: [(Int, String)] = [(8, "morning"), (14, "afternoon"), (18, "evening"), (23, "night")]
        for theme in ["Jarvis", "Warm", "Minimal"] {
            openRitual()
            tap(app.segmentedControls["theme-picker"].buttons[theme])
            back()
            openDebug()
            for (hour, period) in periods {
                tap(app.buttons["hour-\(hour)"])
                let seq = playAndWait(app.buttons["fake-connect"])
                XCTAssertEqual(row("clip_started", in: seq)?["file"] as? String, "\(theme.lowercased())-\(period).mp3", "\(theme) \(period)")
                XCTAssertNil(row("speech_started", in: seq), "voice is off, no speech expected")
                XCTAssertNotNil(row("sequence_finished", in: seq))
            }
            shot("debug-after-\(theme)")
            back()
        }
    }

    // MARK: 5. Ritual settings persist

    func testRitualSettingsPersistAcrossRelaunch() {
        launch(hour: 9)
        openRitual()
        let stepper = app.steppers["pause-stepper"]
        reveal(stepper)
        XCTAssertTrue(stepper.label.contains("0 s"), "default pause must be 0: \(stepper.label)")
        for _ in 0..<7 { stepper.buttons["Increment"].tap() }
        XCTAssertTrue(stepper.label.contains("5 s"), "pause clamps at 5: \(stepper.label)")
        for _ in 0..<2 { stepper.buttons["Decrement"].tap() }
        XCTAssertTrue(stepper.label.contains("3 s"), stepper.label)
        tap(app.segmentedControls["theme-picker"].buttons["Warm"])
        setSwitch("voice-toggle", on: false)
        shot("ritual-changed")
        back()

        relaunch(hour: 9)
        openRitual()
        XCTAssertTrue(app.segmentedControls["theme-picker"].buttons["Warm"].isSelected, "theme did not persist")
        XCTAssertFalse(switchIsOn("voice-toggle"), "voice toggle did not persist")
        let s2 = app.steppers["pause-stepper"]; reveal(s2)
        XCTAssertTrue(s2.label.contains("3 s"), s2.label)
        shot("ritual-after-relaunch")
        for _ in 0..<6 { s2.buttons["Decrement"].tap() }
        XCTAssertTrue(s2.label.contains("0 s"), "pause clamps at 0: \(s2.label)")
    }

    // MARK: 6. Briefing items change the spoken text

    func testBriefingItemTogglesChangeTheSpokenText() {
        launch(hour: 9)
        openDebug()
        for _ in 0..<3 { tap(app.buttons["sim-usual"]) }
        for _ in 0..<3 { tap(app.buttons["sim-streak"]) }
        shot("debug-drives-added")
        XCTAssertTrue(app.staticTexts["drive-summary"].label.contains("Streak 3 days"), app.staticTexts["drive-summary"].label)

        var seq = playAndWait(app.buttons["briefing-only"])
        var raw = rawText(seq), norm = normalisedText(seq)
        XCTAssertTrue(raw.contains("Mohit") && raw.contains("Your Meridian is ready."), raw)   // briefing-only: full greeting
        XCTAssertTrue(raw.contains("Clinic at 9:"), raw)
        XCTAssertTrue(norm.contains("Clinic at nine"), norm)                  // times spoken as words
        XCTAssertTrue(norm.contains("minutes"), norm)
        XCTAssertTrue(raw.contains("3 days in a row"), raw)
        XCTAssertTrue(raw.hasSuffix("Have a good drive."), raw)
        XCTAssertNil(row("clip_started", in: seq), "briefing-only must not play the clip")
        shot("briefing-all-on")
        back()

        openRitual()
        tap(app.switches["item-usualStop"])
        back(); openDebug()
        seq = playAndWait(app.buttons["briefing-only"])
        XCTAssertFalse(rawText(seq).contains("Clinic"), rawText(seq))
        XCTAssertTrue(rawText(seq).contains("in a row"), rawText(seq))
        back()

        openRitual()
        tap(app.switches["item-streak"])
        back(); openDebug()
        seq = playAndWait(app.buttons["briefing-only"])
        XCTAssertFalse(rawText(seq).contains("in a row"), rawText(seq))
        XCTAssertTrue(rawText(seq).hasSuffix("Your Meridian is ready. Have a good drive."), rawText(seq))
        shot("briefing-items-off")
    }

    // MARK: 7. Greeting choice and spoken name

    func testGreetingChoiceAndSpokenName() {
        launch(hour: 18)
        openRitual()
        let field = app.textFields["spoken-name"]
        tap(field)
        field.typeText("Moe-hit")
        dismissKeyboard()
        let second = app.staticTexts["Evening, Mohit. Time to head home."].firstMatch
        reveal(second)
        second.tap()
        shot("greeting-and-spoken-name")
        back()
        openDebug()
        let seq = playAndWait(app.buttons["briefing-only"])
        let raw = rawText(seq)
        XCTAssertTrue(raw.hasPrefix("Evening, Moe-hit. Time to head home."), raw)
        XCTAssertFalse(raw.contains("Mohit"), raw)
        XCTAssertTrue(normalisedText(seq).contains("Moe hit"), normalisedText(seq))
        back()
        XCTAssertEqual(app.staticTexts["home-name"].label, "Mohit", "the screen keeps the real name")
    }

    // MARK: 8. Loved-one recorder UI

    func testLovedOneRecorderUI() {
        addUIInterruptionMonitor(withDescription: "microphone permission") { alert in
            for b in ["Allow", "OK", "Allow While Using App"] where alert.buttons[b].exists { alert.buttons[b].tap(); return true }
            return false
        }
        launch(hour: 18)
        openRitual()
        let label = app.textFields["loved-label"]
        tap(label); label.typeText("Papa")
        dismissKeyboard()
        tap(app.buttons["loved-record"])
        app.tap()   // lets the interruption monitor run
        shot("loved-after-record-tap")
        let recording = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Stop'")).firstMatch
        let denied = app.staticTexts["Microphone access is off. Allow it in Settings, then tap Record again."]
        let failed = app.staticTexts["Recording did not work. Try again."]
        let end = Date().addingTimeInterval(10)
        while Date() < end && !(recording.exists || denied.exists || failed.exists) { Thread.sleep(forTimeInterval: 0.3) }
        let outcome = recording.exists ? "recording-started" : denied.exists ? "permission-denied" : failed.exists ? "recording-failed" : "no-state"
        NSLog("FINDING loved-one-recorder outcome=\(outcome)")
        XCTAssertNotEqual(outcome, "no-state", "recorder UI reached no valid state")
        if recording.exists {
            Thread.sleep(forTimeInterval: 2)
            recording.tap()
            shot("loved-recorded")
            XCTAssertTrue(app.buttons["Play clip"].waitForExistence(timeout: 5), "clip should be offered after recording")
            back()
            let seq = playAndWait(app.buttons["test-welcome"])
            let files = seq.filter { $0["stage"] as? String == "clip_started" }.compactMap { $0["file"] as? String }
            XCTAssertTrue(files.contains { $0.hasPrefix("loved-one") }, "loved-one clip missing from \(files)")
        }
    }

    // MARK: 9. Second car and profile switcher

    func testSecondCarAndSwitcherDriveBriefingAndWidget() {
        launch(hour: 18)
        tap(app.buttons["add-car"])
        XCTAssertTrue(app.staticTexts["Which car do you drive?"].waitForExistence(timeout: 10))
        let search = app.textFields["car-search"]
        search.tap(); search.typeText("Creta")
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Hyundai Creta'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5)); row.tap()
        app.buttons["onboarding-next"].tap()
        app.staticTexts["Atlas White"].firstMatch.tap()
        app.buttons["onboarding-next"].tap()
        let name = app.textFields["owner-name"]; name.tap(); name.typeText("Asha")
        dismissKeyboard()
        shot("second-car-names")
        app.buttons["onboarding-next"].tap()
        XCTAssertTrue(app.buttons["test-welcome"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["home-name"].label, "Asha")
        shot("home-second-car")

        openDebug()
        XCTAssertTrue(app.staticTexts["widget-snapshot"].label.contains("car Creta"), app.staticTexts["widget-snapshot"].label)
        var seq = playAndWait(app.buttons["briefing-only"])
        XCTAssertTrue(rawText(seq).contains("Asha") && rawText(seq).contains("Creta"), rawText(seq))
        back()

        // Switch back through the menu: the active profile feeds briefing and widget.
        tap(app.buttons.matching(NSPredicate(format: "label CONTAINS 'switch'")).firstMatch)
        shot("switcher-menu")
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'Meridian'")).firstMatch.tap()
        XCTAssertEqual(app.staticTexts["home-name"].label, "Mohit")
        openDebug()
        XCTAssertTrue(app.staticTexts["widget-snapshot"].label.contains("car Meridian"), app.staticTexts["widget-snapshot"].label)
        seq = playAndWait(app.buttons["briefing-only"])
        XCTAssertTrue(rawText(seq).contains("Mohit") && rawText(seq).contains("Meridian"), rawText(seq))
        shot("debug-after-switch")
        back()

        relaunch(hour: 18)
        XCTAssertEqual(app.staticTexts["home-name"].label, "Mohit", "active profile did not persist")
    }

    // MARK: 10. Shortcut helper

    func testShortcutHelperChecklistPersists() {
        launch()
        openLink("Set up “CarPlay connects” shortcut")
        XCTAssertTrue(app.buttons["open-shortcuts"].waitForExistence(timeout: 5), "Open Shortcuts button missing")
        for i in 0..<4 { XCTAssertEqual(app.buttons["shortcut-step-\(i)"].value as? String, "todo") }
        tap(app.buttons["shortcut-step-0"]); tap(app.buttons["shortcut-step-2"])
        XCTAssertEqual(app.buttons["shortcut-step-0"].value as? String, "done")
        XCTAssertEqual(app.buttons["shortcut-step-1"].value as? String, "todo")
        XCTAssertEqual(app.buttons["shortcut-step-2"].value as? String, "done")
        shot("shortcut-two-ticked")
        relaunch()
        openLink("Set up “CarPlay connects” shortcut")
        XCTAssertEqual(app.buttons["shortcut-step-0"].value as? String, "done", "tick did not persist")
        XCTAssertEqual(app.buttons["shortcut-step-2"].value as? String, "done")
        XCTAssertEqual(app.buttons["shortcut-step-3"].value as? String, "todo")
        shot("shortcut-after-relaunch")
    }

    // MARK: 11. Debug tools and exports

    func testDebugToolsAndExports() {
        launch(hour: 9)
        openDebug()
        XCTAssertTrue(app.staticTexts["drive-summary"].label.contains("Streak 0 days"))
        for _ in 0..<3 { tap(app.buttons["sim-usual"]) }
        for _ in 0..<2 { tap(app.buttons["sim-streak"]) }
        XCTAssertTrue(app.staticTexts["drive-summary"].label.contains("Streak 2 days"), app.staticTexts["drive-summary"].label)
        tap(app.buttons["clear-drives"])
        XCTAssertTrue(app.staticTexts["drive-summary"].label.contains("Streak 0 days"))
        _ = playAndWait(app.buttons["fake-connect"])
        tap(app.buttons["Refresh"])
        let files = app.staticTexts["files-summary"].label
        NSLog("FINDING files-summary=\(files)")
        XCTAssertFalse(files.contains("metrics.jsonl 0 bytes"), files)
        XCTAssertFalse(files.contains("diagnostics.jsonl 0 bytes"), files)
        XCTAssertTrue(FileManager.default.fileExists(atPath: "\(folder)/metrics.jsonl"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: "\(folder)/diagnostics.jsonl"))
        XCTAssertTrue(metricsEvents().contains("connect_detected"))
        shot("debug-files")

        let export = app.buttons["export-diagnostics"]
        tap(export)
        let sheet = app.otherElements["ActivityListView"]
        let appeared = sheet.waitForExistence(timeout: 8) || app.buttons["Copy"].waitForExistence(timeout: 3)
        NSLog("FINDING share-sheet-appeared=\(appeared)")
        shot("share-sheet")
        XCTAssertTrue(appeared, "share sheet for diagnostics export did not open")
        if app.buttons["Close"].exists { app.buttons["Close"].tap() } else { app.swipeDown() }

        tap(app.buttons["clear-logs"])
        Thread.sleep(forTimeInterval: 0.6)
        XCTAssertFalse(FileManager.default.fileExists(atPath: "\(folder)/diagnostics.jsonl"))
    }

    // MARK: 12. Widget style and accent

    func testWidgetStyleAndAccentFollowSettingsAndPersist() {
        launch(hour: 18, colour: "Galaxy Blue")
        shot("home-blue-accent")
        openDebug()
        var w = app.staticTexts["widget-snapshot"].label
        XCTAssertTrue(w.contains("accent #5B9BD5") && w.contains("style car-large"), w)
        back()
        openRitual()
        let picker = app.segmentedControls["widget-style-picker"]
        reveal(picker)
        picker.buttons["Minimal"].tap()
        shot("widget-minimal-selected")
        back(); openDebug()
        w = app.staticTexts["widget-snapshot"].label
        XCTAssertTrue(w.contains("style minimal"), w)
        back()
        relaunch(hour: 18)
        openRitual()
        reveal(app.segmentedControls["widget-style-picker"])
        XCTAssertTrue(app.segmentedControls["widget-style-picker"].buttons["Minimal"].isSelected, "widget style did not persist")
        back(); openDebug()
        XCTAssertTrue(app.staticTexts["widget-snapshot"].label.contains("style minimal"))
    }

    // MARK: 13. Debounce and interruption

    func testRapidTapsAreIgnoredAndOtherSurfaceInterrupts() {
        launch(hour: 18)
        let before = count("sequence_finished")
        let button = app.buttons["test-welcome"]
        tap(button)
        button.tap(); button.tap()
        XCTAssertTrue(waitFor("sequence_finished", moreThan: before))
        let seq = rows()
        XCTAssertEqual(stages(seq).filter { $0 == "sequence_started" }.count, 1, "\(stages(seq))")
        XCTAssertGreaterThanOrEqual(stages(seq).filter { $0 == "duplicate_ignored" }.count, 1, "\(stages(seq))")
        XCTAssertFalse(metricsEvents().isEmpty)

        // Another surface (debug) while the phone sequence plays: interrupts it, the new one finishes.
        tap(button)
        openDebug()
        tap(app.buttons["fake-connect"])
        XCTAssertTrue(waitFor("sequence_interrupted", moreThan: 0, timeout: 20))
        XCTAssertTrue(waitFor("sequence_finished", moreThan: 1))
        XCTAssertTrue(metricsEvents().contains("sequence_interrupted"))
        shot("after-interrupt")
    }
}
