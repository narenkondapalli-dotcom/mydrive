import SwiftUI

/// Measurement viewer: shows metrics.jsonl, fake connect, simulated drives, export via share sheet.
struct DebugView: View {
    @ObservedObject var model: AppModel
    @State private var log = Metrics.shared.readAll()

    var body: some View {
        List {
            Section {
                Button("Fake CarPlay connect + welcome") {
                    Metrics.shared.markConnect()
                    DriveAudioEngine.shared.playWelcomeSequence()
                }
                Button("Refresh") { log = Metrics.shared.readAll() }
                ShareLink(item: Metrics.shared.fileURL) { Label("Export metrics.jsonl", systemImage: "square.and.arrow.up") }
                Button("Clear log", role: .destructive) { Metrics.shared.clear(); log = "" }
            }
            Section {
                Button("Add simulated drive: usual stop (Home to Clinic, one per week)") { model.addSimulatedDrive(.usualStop) }
                Button("Add simulated drive: streak (Home to Office, one per day)") { model.addSimulatedDrive(.streak) }
                Button("Clear all drives", role: .destructive) { model.clearDrives() }
                Text(driveSummary).font(.footnote).foregroundStyle(.secondary)
            } header: {
                Text("Drive log (\(model.drives.count) drives)")
            } footer: {
                Text("Three usual-stop drives make Clinic a usual stop, spoken in the briefing on the same weekday and hour. Real drive capture is not in this build.")
            }
            Section("Events (newest last)") {
                Text(log.isEmpty ? "No events yet" : log).font(.system(.caption2, design: .monospaced))
            }
        }
        .navigationTitle("Debug")
    }

    private var driveSummary: String {
        let streak = DriveStats.streak(model.drives, today: Date())
        let km = Int(DriveStats.totalDistanceKm(model.drives).rounded())
        return "Streak \(streak) days · \(km) km total"
    }
}
