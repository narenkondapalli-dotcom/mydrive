import Foundation

/// Everything the widget draws, built from App Group data only (so it works on a locked phone).
/// The widget's timeline entry wraps this; the logic lives here so the app's unit tests cover it.
struct WidgetSnapshot: Equatable {
    var carName: String
    var title: String
    var detail: String
    var style: WidgetStyle
    var accentHex: String
    var streak: Int
    var totalKm: Int
    var carImagePath: String?

    static let refreshInterval: TimeInterval = 15 * 60

    static func refreshDate(after now: Date) -> Date { now.addingTimeInterval(refreshInterval) }

    static let empty = WidgetSnapshot(carName: "My Drive", title: "Ready", detail: "Have a good drive", style: .carLarge,
                                      accentHex: Accent.fallbackHex, streak: 0, totalKm: 0, carImagePath: nil)

    static func make(profile: CarProfile?, nextUp: SharedStore.NextUp?, drives: [Drive], now: Date,
                     calendar: Calendar = .current) -> WidgetSnapshot {
        guard let profile else { return .empty }
        var title = "Ready", detail = "Have a good drive"
        if let nextUp {
            title = nextUp.title; detail = nextUp.detail
        } else if let stop = DriveStats.matchingStop(DriveStats.usualStops(drives, calendar: calendar), now: now, calendar: calendar) {
            title = stop.label; detail = "\(stop.avgMinutes) min"
        }
        return WidgetSnapshot(carName: profile.displayName, title: title, detail: detail, style: profile.widgetStyle,
                              accentHex: profile.accentHex,
                              streak: DriveStats.streak(drives, today: now, calendar: calendar),
                              totalKm: Int(DriveStats.totalDistanceKm(drives).rounded()),
                              carImagePath: SharedStore.carImageURL(for: profile)?.path)
    }

    static func load(now: Date = Date()) -> WidgetSnapshot {
        make(profile: SharedStore.loadProfile(), nextUp: SharedStore.loadNextUp(), drives: DriveLogStore.load(), now: now)
    }
}
