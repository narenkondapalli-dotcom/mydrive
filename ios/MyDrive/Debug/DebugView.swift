import SwiftUI

/// Measurement viewer: shows metrics.jsonl, fake connect, export via share sheet.
struct DebugView: View {
    @State private var log = Metrics.shared.readAll()

    var body: some View {
        List {
            Section {
                Button("Fake CarPlay connect + welcome") {
                    Metrics.shared.markConnect()
                    DriveAudioEngine.shared.playWelcomeSequence(briefing: BriefingBuilder.build())
                }
                Button("Refresh") { log = Metrics.shared.readAll() }
                ShareLink(item: Metrics.shared.fileURL) { Label("Export metrics.jsonl", systemImage: "square.and.arrow.up") }
                Button("Clear log", role: .destructive) { Metrics.shared.clear(); log = "" }
            }
            Section("Events (newest last)") {
                Text(log.isEmpty ? "No events yet" : log).font(.system(.caption2, design: .monospaced))
            }
        }
        .navigationTitle("Debug")
    }
}
