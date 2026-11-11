import SwiftUI

/// Measurement viewer: shows metrics.jsonl and diagnostics.jsonl, fake connect, simulated drives, export via share sheet.
struct DebugView: View {
    @ObservedObject var model: AppModel
    @StateObject private var audio = DriveAudioEngine.shared
    @State private var log = Metrics.shared.readAll()
    @State private var diag = Diagnostics.shared.readAll()
    private let tick = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        List {
            if UITestSupport.isActive { testControls }
            Section {
                Button("Fake CarPlay connect + welcome") {
                    Metrics.shared.markConnect()
                    DriveAudioEngine.shared.playWelcomeSequence(surface: "debug")
                    refresh()
                }
                .accessibilityIdentifier("fake-connect")
                Button("Speak briefing only (no clip)") {
                    DriveAudioEngine.shared.playWelcomeSequence(briefingOnly: true, surface: "debug")
                    refresh()
                }
                .accessibilityIdentifier("briefing-only")
                Button("Refresh") { refresh() }
                ShareLink(item: Metrics.shared.fileURL) { Label("Export metrics.jsonl", systemImage: "square.and.arrow.up") }
                    .accessibilityIdentifier("export-metrics")
                ShareLink(item: Diagnostics.shared.fileURL) { Label("Export diagnostics.jsonl", systemImage: "square.and.arrow.up") }
                    .accessibilityIdentifier("export-diagnostics")
                Button("Clear logs", role: .destructive) {
                    Metrics.shared.clear(); Diagnostics.shared.clear(); refresh()
                }
                .accessibilityIdentifier("clear-logs")
                Text(filesSummary).font(.footnote).foregroundStyle(.secondary).accessibilityIdentifier("files-summary")
            }
            Section("Voice") {
                Text(voiceSummary).font(.footnote).accessibilityIdentifier("voice-summary")
                if let hint = VoiceChooser.hint(for: audio.voice) { Text(hint).font(.footnote).foregroundStyle(.secondary) }
            }
            Section("Widget (what it would show now)") {
                Text(widgetSummary).font(.footnote).accessibilityIdentifier("widget-snapshot")
            }
            Section {
                Button("Add simulated drive: usual stop (Home to Clinic, one per week)") { model.addSimulatedDrive(.usualStop) }
                    .accessibilityIdentifier("sim-usual")
                Button("Add simulated drive: streak (Home to Office, one per day)") { model.addSimulatedDrive(.streak) }
                    .accessibilityIdentifier("sim-streak")
                Button("Clear all drives", role: .destructive) { model.clearDrives() }
                    .accessibilityIdentifier("clear-drives")
                Text(driveSummary).font(.footnote).foregroundStyle(.secondary).accessibilityIdentifier("drive-summary")
            } header: {
                Text("Drive log (\(model.drives.count) drives)")
            } footer: {
                Text("Three usual-stop drives make Clinic a usual stop, spoken in the briefing on the same weekday and hour. Real drive capture is not in this build.")
            }
            Section("Diagnostics (newest last)") {
                Text(diag.isEmpty ? "No diagnostics yet" : Diagnostics.shared.tail(40)).font(.system(size: 9, design: .monospaced))
            }
            Section("Events (newest last)") {
                Text(log.isEmpty ? "No events yet" : log).font(.system(.caption2, design: .monospaced))
            }
        }
        .overlay(alignment: .topLeading) {
            // Test hooks: always in the accessibility tree, whatever the scroll position. Only in UI test mode.
            if UITestSupport.isActive {
                VStack(alignment: .leading, spacing: 0) {
                    Text(diag).accessibilityIdentifier("diag-log")
                    Text(log).accessibilityIdentifier("metrics-log")
                }
                .font(.system(size: 1)).foregroundStyle(.clear).frame(width: 1, height: 1).clipped()
            }
        }
        .onReceive(tick) { _ in refresh() }
        .navigationTitle("Debug")
    }

    private var testControls: some View {
        Section("Test controls (UI tests only)") {
            ForEach([8, 14, 18, 23], id: \.self) { h in
                Button("Set hour \(h)") { UITestSupport.setHour(h); refresh() }.accessibilityIdentifier("hour-\(h)")
            }
        }
    }

    private func refresh() {
        log = Metrics.shared.readAll()
        diag = Diagnostics.shared.readAll()
    }

    private var driveSummary: String {
        let streak = DriveStats.streak(model.drives, today: AppClock.now)
        let km = Int(DriveStats.totalDistanceKm(model.drives).rounded())
        return "Streak \(streak) days · \(km) km total"
    }

    private var filesSummary: String {
        func size(_ u: URL) -> Int { ((try? FileManager.default.attributesOfItem(atPath: u.path)[.size]) as? Int) ?? 0 }
        return "metrics.jsonl \(size(Metrics.shared.fileURL)) bytes · diagnostics.jsonl \(size(Diagnostics.shared.fileURL)) bytes"
    }

    private var voiceSummary: String {
        let r = VoiceChooser.current()
        guard let c = r.chosen else { return "No English voice found" }
        return "\(c.name) · \(c.language) · \(c.qualityName) · \(r.ranked.count) usable voices"
    }

    private var widgetSummary: String {
        let s = WidgetSnapshot.make(profile: model.active, nextUp: SharedStore.loadNextUp(), drives: model.drives, now: AppClock.now)
        return "car \(s.carName) · \(s.title) · \(s.detail) · style \(s.style.rawValue) · accent \(s.accentHex) · streak \(s.streak) · km \(s.totalKm)"
    }
}
