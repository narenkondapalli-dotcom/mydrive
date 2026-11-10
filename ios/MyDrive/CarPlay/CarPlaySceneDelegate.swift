import CarPlay
import UIKit

/// The car-screen side of My Drive: an audio app with three tabs (Today, Library, Drives).
/// Only Apple templates are used. iOS 27 additions (thumbnails, details header, CPPlaybackConfiguration,
/// voice control for audio apps) are added behind `if #available(iOS 27, *)` once the SDK is installed.
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private var interfaceController: CPInterfaceController?

    func templateApplicationScene(_ scene: CPTemplateApplicationScene,
                                  didConnect interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
        Metrics.shared.markConnect()
        Metrics.shared.log(.appLaunched, ["surface": "carplay"])

        let tabs = CPTabBarTemplate(templates: [todayTab(), libraryTab(), drivesTab()])
        interfaceController.setRootTemplate(tabs, animated: false, completion: nil)
    }

    func templateApplicationScene(_ scene: CPTemplateApplicationScene,
                                  didDisconnectInterfaceController interfaceController: CPInterfaceController) {
        self.interfaceController = nil
    }

    // MARK: - Tabs

    private func todayTab() -> CPListTemplate {
        let profile = SharedStore.loadProfile()
        let welcome = CPListItem(text: "Welcome theme",
                                 detailText: profile.map { "\($0.displayName) · Signature" } ?? "Signature",
                                 image: artwork(size: 200))
        welcome.handler = { [weak self] _, done in
            self?.play(theme: "signature"); done()
        }
        let briefing = CPListItem(text: "Today's briefing",
                                  detailText: SharedStore.loadNextUp()?.title ?? "Weather · first event · traffic",
                                  image: UIImage(systemName: "sun.horizon"))
        briefing.handler = { [weak self] _, done in
            self?.play(theme: "none"); done()
        }
        let t = CPListTemplate(title: "Today", sections: [CPListSection(items: [welcome, briefing])])
        t.tabImage = UIImage(systemName: "sun.max")
        return t
    }

    private func libraryTab() -> CPListTemplate {
        let themes = ["Signature", "Calm", "Grand"].map { name -> CPListItem in
            let item = CPListItem(text: name, detailText: "Welcome theme")
            item.handler = { [weak self] _, done in self?.play(theme: name.lowercased()); done() }
            return item
        }
        let t = CPListTemplate(title: "Library", sections: [CPListSection(items: themes, header: "Themes", sectionIndexTitle: nil)])
        t.tabImage = UIImage(systemName: "music.note.list")
        return t
    }

    private func drivesTab() -> CPListTemplate {
        // v0: placeholder rows; v1 reads past drives from the metrics log.
        let t = CPListTemplate(title: "Drives", sections: [CPListSection(items: [CPListItem(text: "Recent drives appear here", detailText: nil)])])
        t.tabImage = UIImage(systemName: "car")
        return t
    }

    // MARK: - Actions

    private func play(theme: String) {
        Task { @MainActor in
            let text = BriefingBuilder.build()
            if theme == "none" {
                DriveAudioEngine.shared.playWelcomeSequence(theme: "none", briefing: text)
            } else {
                DriveAudioEngine.shared.playWelcomeSequence(theme: theme, briefing: text)
            }
        }
        interfaceController?.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil)
    }

    private func artwork(size: CGFloat) -> UIImage? {
        guard let p = SharedStore.loadProfile() else { return UIImage(systemName: "car.fill") }
        return ArtworkComposer.compose(profile: p, line1: "", line2: "", side: size)
    }
}
