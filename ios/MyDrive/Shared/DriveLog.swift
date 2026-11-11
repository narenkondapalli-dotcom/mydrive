import Foundation

/// P3: one drive. Local only.
struct Drive: Codable, Equatable, Identifiable {
    var id: String = UUID().uuidString
    var startTs: Date
    var endTs: Date
    var distanceKm: Double
    var startLabel: String
    var endLabel: String

    var minutes: Double { endTs.timeIntervalSince(startTs) / 60 }
}

struct UsualStop: Equatable {
    var label: String
    var count: Int
    var weekday: Int          // Calendar weekday of the typical departure (1 = Sunday)
    var hour: Int             // typical departure hour
    var avgMinutes: Int       // average trip time
    var arrivalMinuteOfDay: Int
}

struct RouteStat: Equatable {
    var start: String
    var end: String
    var count: Int
}

/// Derived figures from the drive log. Pure functions, so they are unit tested.
enum DriveStats {
    static let usualStopMinimum = 3

    static func totalDistanceKm(_ drives: [Drive]) -> Double { drives.reduce(0) { $0 + $1.distanceKm } }

    /// End labels seen at least `minCount` times, most frequent first.
    static func usualStops(_ drives: [Drive], minCount: Int = usualStopMinimum, calendar: Calendar = .current) -> [UsualStop] {
        Dictionary(grouping: drives, by: { $0.endLabel }).compactMap { label, group -> UsualStop? in
            guard !label.isEmpty, group.count >= minCount else { return nil }
            let avg = group.reduce(0) { $0 + $1.minutes } / Double(group.count)
            let arrivals = group.map { d -> Int in
                calendar.component(.hour, from: d.endTs) * 60 + calendar.component(.minute, from: d.endTs)
            }
            return UsualStop(label: label, count: group.count,
                             weekday: mode(group.map { calendar.component(.weekday, from: $0.startTs) }),
                             hour: mode(group.map { calendar.component(.hour, from: $0.startTs) }),
                             avgMinutes: Int(avg.rounded()),
                             arrivalMinuteOfDay: arrivals.reduce(0, +) / arrivals.count)
        }
        .sorted { $0.count != $1.count ? $0.count > $1.count : $0.label < $1.label }
    }

    /// Consecutive days with a drive. A streak is still alive if the last drive was yesterday.
    static func streak(_ drives: [Drive], today: Date, calendar: Calendar = .current) -> Int {
        let days = Set(drives.map { calendar.startOfDay(for: $0.startTs) })
        var day = calendar.startOfDay(for: today)
        if !days.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day), days.contains(yesterday) else { return 0 }
            day = yesterday
        }
        var count = 0
        while days.contains(day) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    /// Most frequent start to end pair. Ties go to the alphabetically first pair.
    static func favouriteRoute(_ drives: [Drive]) -> RouteStat? {
        let groups = Dictionary(grouping: drives.filter { !$0.startLabel.isEmpty && !$0.endLabel.isEmpty },
                                by: { "\($0.startLabel)\u{1}\($0.endLabel)" })
        return groups.values
            .map { RouteStat(start: $0[0].startLabel, end: $0[0].endLabel, count: $0.count) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : ($0.start, $0.end) < ($1.start, $1.end) }
            .first
    }

    /// A usual stop whose weekday matches today and whose typical departure hour is within one hour of now.
    static func matchingStop(_ stops: [UsualStop], now: Date, calendar: Calendar = .current) -> UsualStop? {
        let weekday = calendar.component(.weekday, from: now)
        let hour = calendar.component(.hour, from: now)
        return stops.first { stop in
            let diff = abs(stop.hour - hour)
            return stop.weekday == weekday && min(diff, 24 - diff) <= 1
        }
    }

    /// "Clinic at 9:30 — 32 min"
    static func usualStopLine(_ stop: UsualStop) -> String {
        let h = stop.arrivalMinuteOfDay / 60, m = stop.arrivalMinuteOfDay % 60
        let h12 = h % 12 == 0 ? 12 : h % 12
        return "\(stop.label) at \(h12):" + String(format: "%02d", m) + " — \(stop.avgMinutes) min"
    }

    static func recent(_ drives: [Drive], limit: Int) -> [Drive] {
        Array(drives.sorted { $0.startTs > $1.startTs }.prefix(limit))
    }

    /// Most frequent value; ties go to the smallest.
    private static func mode(_ values: [Int]) -> Int {
        let counts = Dictionary(values.map { ($0, 1) }, uniquingKeysWith: +)
        return counts.max { a, b in a.value != b.value ? a.value < b.value : a.key > b.key }?.key ?? 0
    }
}

/// Local drive log in the App Group container.
enum DriveLogStore {
    static var url: URL { SharedStore.containerURL.appendingPathComponent("drive-log.json") }

    static func load() -> [Drive] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        return (try? dec.decode([Drive].self, from: data)) ?? []
    }

    static func save(_ drives: [Drive]) throws {
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
        try SharedStore.write(try enc.encode(drives), to: url)
    }

    @discardableResult
    static func add(_ drive: Drive) -> [Drive] {
        let all = load() + [drive]
        try? save(all)
        return all
    }

    static func clear() { try? FileManager.default.removeItem(at: url) }
}

/// Debug helper: invents drives so the stats can be seen without real capture.
enum SimulatedDrive {
    enum Kind { case usualStop, streak }

    /// `.usualStop`: Home to Clinic, same weekday and hour, one per week back (index 0 = today).
    /// `.streak`: Home to Office, one per consecutive day back (index 0 = today).
    static func make(kind: Kind, index: Int, now: Date = Date(), calendar: Calendar = .current) -> Drive {
        let daysBack = kind == .usualStop ? index * 7 : index
        let day = calendar.date(byAdding: .day, value: -daysBack, to: now) ?? now
        let start = calendar.date(from: calendar.dateComponents([.year, .month, .day, .hour], from: day)) ?? day
        let minutes = kind == .usualStop ? 32.0 : 24.0
        return Drive(startTs: start, endTs: start.addingTimeInterval(minutes * 60),
                     distanceKm: kind == .usualStop ? 14.2 : 9.6,
                     startLabel: "Home", endLabel: kind == .usualStop ? "Clinic" : "Office")
    }
}
