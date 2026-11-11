import Foundation

/// P2: time-of-day greeting copy from shared/briefing/greetings.json (bundled).
/// Periods are inclusive hour ranges; a range with start > end wraps past midnight (night = 21 to 4).
struct GreetingBook: Equatable {
    struct Slot: Codable, Equatable {
        var hours: [Int]
        var lines: [String]
    }

    var slots: [String: Slot]

    static func parse(_ data: Data) throws -> GreetingBook {
        GreetingBook(slots: try JSONDecoder().decode([String: Slot].self, from: data))
    }

    static func load(bundle: Bundle = .main) -> GreetingBook? {
        guard let url = bundle.url(forResource: "greetings", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? parse(data)
    }

    /// Used only if the bundled file is missing. Same copy as the JSON.
    static let fallback = GreetingBook(slots: [
        "morning": Slot(hours: [5, 11], lines: ["Good morning, {name}."]),
        "afternoon": Slot(hours: [12, 16], lines: ["Good afternoon, {name}."]),
        "evening": Slot(hours: [17, 20], lines: ["Good evening, {name}."]),
        "night": Slot(hours: [21, 4], lines: ["Good evening, {name}. Drive safe."]),
    ])

    func period(forHour hour: Int) -> String? {
        slots.first { _, slot in
            guard slot.hours.count == 2 else { return false }
            let lo = slot.hours[0], hi = slot.hours[1]
            return lo <= hi ? (lo...hi).contains(hour) : (hour >= lo || hour <= hi)
        }?.key
    }

    func lines(forHour hour: Int) -> [String] {
        period(forHour: hour).flatMap { slots[$0]?.lines } ?? []
    }

    /// Picks the greeting. `index` is the driver's own choice; otherwise `seed` (for example the day of the year) rotates the lines.
    func pick(hour: Int, name: String, index: Int? = nil, seed: Int = 0) -> String {
        let options = lines(forHour: hour)
        guard !options.isEmpty else { return name.isEmpty ? "Hello." : "Hello, \(name)." }
        let i = ((index ?? seed) % options.count + options.count) % options.count
        return Self.fill(options[i], name: name)
    }

    static func fill(_ line: String, name: String) -> String {
        if name.isEmpty {
            return line.replacingOccurrences(of: ", {name}", with: "")
                .replacingOccurrences(of: " {name}", with: "")
                .replacingOccurrences(of: "{name}", with: "")
        }
        return line.replacingOccurrences(of: "{name}", with: name)
    }
}
