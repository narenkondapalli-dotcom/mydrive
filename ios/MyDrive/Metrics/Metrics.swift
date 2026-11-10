import Foundation

/// Built-in measurement: one JSON line per event in `metrics.jsonl` (App Group container).
/// Exported from the Debug screen for review. Never blocks the caller.
final class Metrics {
    static let shared = Metrics()

    enum Event: String {
        case connectDetected = "connect_detected", appLaunched = "app_launched"
        case welcomeStarted = "welcome_started", welcomeFinished = "welcome_finished"
        case briefingStarted = "briefing_started", briefingFinished = "briefing_finished"
        case handoffMusic = "handoff_music", widgetRendered = "widget_rendered"
        case onboardingStep = "onboarding_step", onboardingDone = "onboarding_done"
        case error
    }

    private let queue = DispatchQueue(label: "mydrive.metrics")
    private var connectTime: Date?
    let fileURL: URL

    init(fileURL: URL = SharedStore.containerURL.appendingPathComponent("metrics.jsonl")) {
        self.fileURL = fileURL
    }

    func markConnect() {
        connectTime = Date()
        log(.connectDetected)
    }

    func log(_ event: Event, _ extra: [String: String] = [:]) {
        let now = Date()
        let since = connectTime.map { Int(now.timeIntervalSince($0) * 1000) }
        var row: [String: Any] = [
            "ts": ISO8601DateFormatter().string(from: now),
            "event": event.rawValue,
            "platform": "ios",
            "build": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?",
        ]
        if let since { row["ms_since_connect"] = since }
        if !extra.isEmpty { row["extra"] = extra }
        queue.async { [fileURL] in
            guard var line = try? JSONSerialization.data(withJSONObject: row, options: [.sortedKeys]) else { return }
            line.append(0x0A)
            if let h = try? FileHandle(forWritingTo: fileURL) {
                h.seekToEndOfFile(); h.write(line); try? h.close()
            } else {
                try? line.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            }
        }
    }

    func readAll() -> String { (try? String(contentsOf: fileURL, encoding: .utf8)) ?? "" }

    func clear() { queue.async { [fileURL] in try? FileManager.default.removeItem(at: fileURL) } }
}
