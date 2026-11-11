import Foundation

/// Builds the spoken briefing text from the active profile's greeting and the items it switched on.
/// Weather and traffic have no data source yet (WeatherKit / MapKit later); their switches are stored already.
enum BriefingBuilder {
    static func build(now: Date = Date()) -> String {
        compose(profile: SharedStore.loadProfile(), nextUp: SharedStore.loadNextUp(), drives: DriveLogStore.load(),
                greetings: GreetingBook.load() ?? .fallback, now: now)
    }

    static func compose(profile: CarProfile?, nextUp: SharedStore.NextUp?, drives: [Drive], greetings: GreetingBook,
                        now: Date, calendar: Calendar = .current) -> String {
        let hour = calendar.component(.hour, from: now)
        let day = calendar.ordinality(of: .day, in: .year, for: now) ?? 0
        let items = profile?.briefingItems ?? Set(BriefingItem.allCases)
        var lines = [greetings.pick(hour: hour, name: profile?.ownerName ?? "", index: profile?.greetingIndex, seed: day)]
        if let car = profile { lines.append("Your \(car.displayName) is ready.") }
        if items.contains(.calendar), let next = nextUp { lines.append("\(next.title). \(next.detail).") }
        if items.contains(.usualStop),
           let stop = DriveStats.matchingStop(DriveStats.usualStops(drives, calendar: calendar), now: now, calendar: calendar) {
            lines.append(DriveStats.usualStopLine(stop) + ".")
        }
        if items.contains(.streak) {
            let streak = DriveStats.streak(drives, today: now, calendar: calendar)
            if streak >= 2 { lines.append("That's \(streak) days in a row.") }
        }
        lines.append("Have a good drive.")
        return lines.joined(separator: " ")
    }
}
