import Foundation
import os

/// Stage-by-stage trace of a welcome sequence: JSONL in the App Group container (`diagnostics.jsonl`) and os.Logger
/// (subsystem com.biolynk.mydrive). Each line: seq, ts (ISO 8601 with ms), up_ms (monotonic), stage, plus fields.
/// Exported from the Debug screen next to metrics.jsonl.
final class Diagnostics {
    static let shared = Diagnostics()

    private let queue = DispatchQueue(label: "mydrive.diagnostics")
    private let logger = Logger(subsystem: "com.biolynk.mydrive", category: "sequence")
    private var counter = 0
    private let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    /// Always the current container (tests and UI tests swap it).
    var fileURL: URL { SharedStore.containerURL.appendingPathComponent("diagnostics.jsonl") }

    func log(_ stage: String, _ fields: [String: Any] = [:]) {
        let now = Date()
        let up = Int((ProcessInfo.processInfo.systemUptime * 1000).rounded())
        queue.sync {
            counter += 1
            var row: [String: Any] = ["seq": counter, "ts": iso.string(from: now), "up_ms": up, "stage": stage]
            for (k, v) in fields { row[k] = v }
            let text = (try? JSONSerialization.data(withJSONObject: row, options: [.sortedKeys]))
                .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
            logger.info("\(text, privacy: .public)")
            guard var line = text.data(using: .utf8) else { return }
            line.append(0x0A)
            let url = fileURL
            if let h = try? FileHandle(forWritingTo: url) {
                h.seekToEndOfFile(); h.write(line); try? h.close()
            } else {
                try? SharedStore.write(line, to: url)
            }
        }
    }

    func readAll() -> String { queue.sync { (try? String(contentsOf: fileURL, encoding: .utf8)) ?? "" } }

    func tail(_ lines: Int) -> String {
        readAll().split(separator: "\n").suffix(lines).joined(separator: "\n")
    }

    func clear() { queue.sync { try? FileManager.default.removeItem(at: fileURL) } }

    /// Parsed rows, for tests.
    func rows() -> [[String: Any]] {
        readAll().split(separator: "\n").compactMap {
            (try? JSONSerialization.jsonObject(with: Data($0.utf8))) as? [String: Any]
        }
    }
}
