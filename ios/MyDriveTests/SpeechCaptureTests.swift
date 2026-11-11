import AVFoundation
import XCTest
@testable import MyDrive

/// Renders each briefing test case to a WAV with the real chosen voice and the real normalised text, using
/// AVSpeechSynthesizer.write (the same path the app plays). CI uploads /tmp/mydrive-ci-out as an artifact so the
/// spoken result can be transcribed and listened to.
final class SpeechCaptureTests: IsolatedStoreTestCase {
    static let outDir = URL(fileURLWithPath: "/tmp/mydrive-ci-out/speech")

    private struct Case {
        var name: String
        var theme: SoundTheme?          // nil = briefing only (no clip)
        var hour: Int
        var spokenName: String?
        var withDrives: Bool
    }

    private func compose(_ c: Case) -> String {
        var p = profile(name: "Mohit")
        p.spokenName = c.spokenName
        let now = date(2026, 11, 23, c.hour, 15)             // a Monday
        var drives: [Drive] = []
        if c.withDrives {
            drives = (0..<3).map { drive(date(2026, 11, 2 + 7 * $0, c.hour, 0), minutes: 32, km: 14.2) }       // usual stop Clinic
            drives += (0..<4).map { drive(date(2026, 11, 23 - $0, 8, 0), minutes: 24, km: 9.6, from: "Home", to: "Office") }   // streak
        }
        let clip = c.theme.map { ClipCoverage.of(theme: $0, period: DayPeriod.at(hour: c.hour)) } ?? .none
        return BriefingBuilder.compose(profile: p, nextUp: nil, drives: drives, greetings: GreetingBook.load() ?? .fallback,
                                       now: now, clip: clip, calendar: cal)
    }

    func testRenderBriefingCasesToWav() async throws {
        let cases = [
            Case(name: "01-jarvis-evening-full-usualstop-streak", theme: .jarvis, hour: 18, spokenName: nil, withDrives: true),
            Case(name: "02-warm-morning", theme: .warm, hour: 9, spokenName: nil, withDrives: false),
            Case(name: "03-minimal-night", theme: .minimal, hour: 23, spokenName: nil, withDrives: false),
            Case(name: "04-briefing-only-no-clip", theme: nil, hour: 18, spokenName: nil, withDrives: true),
            Case(name: "05-name-Mohit-plain", theme: .jarvis, hour: 18, spokenName: nil, withDrives: false),
            Case(name: "06-name-Mohit-spoken-Moe-hit", theme: .jarvis, hour: 18, spokenName: "Moe-hit", withDrives: false),
        ]
        try FileManager.default.createDirectory(at: Self.outDir, withIntermediateDirectories: true)
        let ranked = VoiceChooser.current()
        let voicesJSON = try JSONEncoder().encode(["chosen": ranked.chosen.map { [$0] } ?? [], "ranked": ranked.ranked])
        try voicesJSON.write(to: Self.outDir.appendingPathComponent("voices.json"))
        let all = AVSpeechSynthesisVoice.speechVoices().map { "\($0.identifier)|\($0.name)|\($0.language)|q\($0.quality.rawValue)" }
        try all.joined(separator: "\n").write(to: Self.outDir.appendingPathComponent("all-system-voices.txt"), atomically: true, encoding: .utf8)

        var manifest: [[String: Any]] = []
        for c in cases {
            let raw = compose(c)
            let prepared = PreparedSpeech.make(raw)
            let r = await SpeechRenderer.render(prepared, timeout: 20)
            var row: [String: Any] = ["case": c.name, "raw": raw, "normalised": prepared.normalised, "ipa": prepared.ipaWords,
                                      "voice": prepared.voice.map { "\($0.name)|\($0.language)|\($0.qualityName)|\($0.identifier)" } ?? "system default",
                                      "render_ms": r.renderMs, "duration_s": (r.duration * 100).rounded() / 100,
                                      "clip_text": c.theme.map { ClipCoverage.of(theme: $0, period: DayPeriod.at(hour: c.hour)).text } ?? "(none)",
                                      "error": r.error ?? "none"]
            if r.isUsable {
                try SpeechRenderer.writeWav(r, to: Self.outDir.appendingPathComponent("\(c.name).wav"))
                row["wav"] = "\(c.name).wav"
            }
            manifest.append(row)
            XCTAssertTrue(r.isUsable, "\(c.name): no audio rendered (\(r.error ?? "empty"))")
            XCTAssertGreaterThan(r.duration, 1.0, c.name)
        }
        let data = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: Self.outDir.appendingPathComponent("manifest.json"))
    }
}
