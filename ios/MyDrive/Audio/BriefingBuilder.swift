import Foundation

/// Builds the spoken briefing text from the active profile's greeting and the items it switched on.
/// Weather and traffic have no data source yet (WeatherKit / MapKit later); their switches are stored already.
///
/// `clip` says what the welcome clip that just played already covered. The text then starts at the driver's name
/// and only adds a closing line the clip did not give. With `.none` (briefing-only path) it is a full greeting.
enum BriefingBuilder {
    static func build(now: Date = AppClock.now, clip: ClipCoverage = .none) -> String {
        compose(profile: SharedStore.loadProfile(), nextUp: SharedStore.loadNextUp(), drives: DriveLogStore.load(),
                greetings: GreetingBook.load() ?? .fallback, now: now, clip: clip)
    }

    static func compose(profile: CarProfile?, nextUp: SharedStore.NextUp?, drives: [Drive], greetings: GreetingBook,
                        now: Date, clip: ClipCoverage = .none, calendar: Calendar = .current) -> String {
        let hour = calendar.component(.hour, from: now)
        let day = calendar.ordinality(of: .day, in: .year, for: now) ?? 0
        let items = profile?.briefingItems ?? Set(BriefingItem.allCases)
        let name = profile?.nameForSpeech ?? ""
        var lines: [String] = []

        if clip.greeting {
            lines.append(opening(name: name, car: profile?.displayName, readyCovered: clip.ready))
        } else {
            lines.append(greetings.pick(hour: hour, name: name, index: profile?.greetingIndex, seed: day))
            if let car = profile { lines.append("Your \(car.displayName) is ready.") }
        }
        if items.contains(.calendar), let next = nextUp { lines.append("\(next.title). \(next.detail).") }
        if items.contains(.usualStop),
           let stop = DriveStats.matchingStop(DriveStats.usualStops(drives, calendar: calendar), now: now, calendar: calendar) {
            lines.append(DriveStats.usualStopLine(stop) + ".")
        }
        if items.contains(.streak) {
            let streak = DriveStats.streak(drives, today: now, calendar: calendar)
            if streak >= 2 { lines.append("That's \(streak) days in a row.") }
        }
        if !clip.safeClosing { lines.append("Have a good drive.") }
        return lines.joined(separator: " ")
    }

    /// First spoken line right after a clip that already said hello (and maybe "ready").
    private static func opening(name: String, car: String?, readyCovered: Bool) -> String {
        switch (name.isEmpty, car) {
        case (false, let car?): return readyCovered ? "\(name), welcome back to your \(car)." : "\(name), your \(car) is ready."
        case (false, nil):      return "\(name)."
        case (true, let car?):  return readyCovered ? "Welcome back to your \(car)." : "Your \(car) is ready."
        case (true, nil):       return "Welcome back."
        }
    }
}
