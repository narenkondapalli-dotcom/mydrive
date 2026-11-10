import Foundation

/// Builds the spoken briefing text. v0: greeting + next-up line saved by the phone app.
/// v1: WeatherKit, EventKit (first event), MapKit ETA.
enum BriefingBuilder {
    static func build(now: Date = Date()) -> String {
        let profile = SharedStore.loadProfile()
        let name = profile?.ownerName ?? ""
        let hour = Calendar.current.component(.hour, from: now)
        let part = hour < 12 ? "Good morning" : (hour < 17 ? "Good afternoon" : "Good evening")
        var lines = [name.isEmpty ? "\(part)." : "\(part), \(name)."]
        if let car = profile { lines.append("Your \(car.displayName) is ready.") }
        if let next = SharedStore.loadNextUp() { lines.append("\(next.title). \(next.detail).") }
        lines.append("Have a good drive.")
        return lines.joined(separator: " ")
    }
}
