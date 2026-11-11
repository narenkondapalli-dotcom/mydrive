import CarPlay
import UIKit

/// Builds the car-screen templates from plain data, so unit tests can inspect them without a CarPlay scene.
/// Only Apple templates are used. iOS 27 additions (thumbnails, details header, CPPlaybackConfiguration,
/// voice control for audio apps) are added behind `if #available(iOS 27, *)` once the SDK is installed.
enum CarPlayTemplates {
    /// What the car screen can ask the app to do.
    struct Actions {
        /// `theme == nil` means the profile's own theme.
        var play: (_ theme: SoundTheme?, _ briefingOnly: Bool) -> Void
    }

    static func root(profile: CarProfile?, nextUp: SharedStore.NextUp?, drives: [Drive], now: Date,
                     artwork: @escaping (CGFloat) -> UIImage?, actions: Actions) -> CPTabBarTemplate {
        CPTabBarTemplate(templates: [today(profile: profile, nextUp: nextUp, artwork: artwork, actions: actions),
                                     library(actions: actions),
                                     drivesTab(drives, now: now)])
    }

    static func today(profile: CarProfile?, nextUp: SharedStore.NextUp?, artwork: (CGFloat) -> UIImage?, actions: Actions) -> CPListTemplate {
        let welcome = CPListItem(text: "Welcome theme",
                                 detailText: profile.map { "\($0.displayName) · \($0.ritual.theme.title)" } ?? "Jarvis",
                                 image: artwork(200))
        welcome.handler = { _, done in actions.play(nil, false); done() }
        let briefing = CPListItem(text: "Today's briefing",
                                  detailText: nextUp?.title ?? "Weather · first event · traffic",
                                  image: UIImage(systemName: "sun.horizon"))
        briefing.handler = { _, done in actions.play(nil, true); done() }
        let t = CPListTemplate(title: "Today", sections: [CPListSection(items: [welcome, briefing])])
        t.tabImage = UIImage(systemName: "sun.max")
        return t
    }

    static func library(actions: Actions) -> CPListTemplate {
        let themes = SoundTheme.allCases.map { theme -> CPListItem in
            let item = CPListItem(text: theme.title, detailText: "Welcome theme")
            item.handler = { _, done in actions.play(theme, false); done() }
            return item
        }
        let t = CPListTemplate(title: "Library", sections: [CPListSection(items: themes, header: "Themes", sectionIndexTitle: nil)])
        t.tabImage = UIImage(systemName: "music.note.list")
        return t
    }

    /// Read-only list: stats and recent drives from the local DriveLog. No settings and no recording on the car screen.
    static func drivesTab(_ drives: [Drive], now: Date, calendar: Calendar = .current) -> CPListTemplate {
        var stats: [CPListItem] = []
        if drives.isEmpty {
            stats.append(CPListItem(text: "No drives yet", detailText: "Your drives appear here"))
        } else {
            let streak = DriveStats.streak(drives, today: now, calendar: calendar)
            stats.append(CPListItem(text: "Streak", detailText: streak == 1 ? "1 day" : "\(streak) days"))
            stats.append(CPListItem(text: "Total distance", detailText: "\(Int(DriveStats.totalDistanceKm(drives).rounded())) km"))
            if let route = DriveStats.favouriteRoute(drives) {
                stats.append(CPListItem(text: "Favourite route", detailText: "\(route.start) to \(route.end) · \(route.count) drives"))
            }
        }
        var sections = [CPListSection(items: stats, header: "Your drives", sectionIndexTitle: nil)]

        let stops = DriveStats.usualStops(drives, calendar: calendar).prefix(4).map { stop in
            CPListItem(text: stop.label, detailText: DriveStats.usualStopLine(stop))
        }
        if !stops.isEmpty { sections.append(CPListSection(items: Array(stops), header: "Usual stops", sectionIndexTitle: nil)) }

        let recent = DriveStats.recent(drives, limit: 5).map { d -> CPListItem in
            CPListItem(text: "\(d.startLabel) to \(d.endLabel)",
                       detailText: "\(Int(d.minutes.rounded())) min · " + String(format: "%.1f km", d.distanceKm))
        }
        if !recent.isEmpty { sections.append(CPListSection(items: recent, header: "Recent", sectionIndexTitle: nil)) }

        let t = CPListTemplate(title: "Drives", sections: sections)
        t.tabImage = UIImage(systemName: "car")
        return t
    }
}

/// The car-screen side of My Drive: an audio app with three tabs (Today, Library, Drives).
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private var interfaceController: CPInterfaceController?

    func templateApplicationScene(_ scene: CPTemplateApplicationScene,
                                  didConnect interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
        Metrics.shared.markConnect()
        Metrics.shared.log(.appLaunched, ["surface": "carplay"])

        let tabs = CarPlayTemplates.root(
            profile: SharedStore.loadProfile(), nextUp: SharedStore.loadNextUp(), drives: DriveLogStore.load(), now: AppClock.now,
            artwork: { [weak self] in self?.artwork(size: $0) },
            actions: .init(play: { [weak self] theme, briefingOnly in self?.play(theme: theme, briefingOnly: briefingOnly) }))
        interfaceController.setRootTemplate(tabs, animated: false, completion: nil)
    }

    func templateApplicationScene(_ scene: CPTemplateApplicationScene,
                                  didDisconnectInterfaceController interfaceController: CPInterfaceController) {
        self.interfaceController = nil
    }

    private func play(theme: SoundTheme?, briefingOnly: Bool) {
        Task { @MainActor in
            DriveAudioEngine.shared.playWelcomeSequence(theme: theme, briefingOnly: briefingOnly, surface: "carplay")
        }
        interfaceController?.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil)
    }

    private func artwork(size: CGFloat) -> UIImage? {
        guard let p = SharedStore.loadProfile() else { return UIImage(systemName: "car.fill") }
        return ArtworkComposer.compose(profile: p, line1: "", line2: "", side: size)
    }
}
