import AVFoundation
import MediaPlayer
import UIKit

/// Finds the bundled welcome sounds (shared/sounds/welcome, copied into the app inside the "sounds" folder).
enum SoundLibrary {
    /// Clip for a theme at this hour, for example "jarvis-morning.mp3". Fixed recordings: the driver's name is spoken afterwards by the on-device voice.
    static func url(for theme: SoundTheme, hour: Int, bundle: Bundle = .main) -> URL? {
        bundle.url(forResource: "\(theme.rawValue)-\(DayPeriod.at(hour: hour).rawValue)", withExtension: "mp3",
                   subdirectory: "sounds/welcome")
    }
}

/// Where the loved-one clip of a profile lives (phone-recorded, local only).
enum LovedOneStore {
    static func url(for profile: CarProfile) -> URL? {
        guard let name = profile.lovedOne.fileName else { return nil }
        return SharedStore.containerURL.appendingPathComponent(name)
    }

    static func isAvailable(_ profile: CarProfile) -> Bool {
        guard profile.lovedOne.enabled, let url = url(for: profile) else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }
}

/// Plays the active profile's ritual: chime, optional loved-one clip, pause, spoken briefing, then hands off to the user's music.
/// Audio session is activated only at the moment sound starts (CarPlay rule: never at launch).
@MainActor
final class DriveAudioEngine: NSObject, ObservableObject {
    static let shared = DriveAudioEngine()

    enum Stage: String { case idle, welcome, lovedOne, briefing, done }
    @Published private(set) var stage: Stage = .idle

    private var player: AVAudioPlayer?
    private let speech = AVSpeechSynthesizer()
    private var briefingText = ""
    private var queue: [RitualStep] = []
    private var runToken = 0

    override init() {
        super.init()
        speech.delegate = self
        setupRemoteCommands()
    }

    /// Entry point used by CarPlay "Today", the Shortcut intent and the debug fake connect.
    /// Uses the active profile's ritual (theme, loved-one clip, delay, voice on/off).
    /// - Parameters:
    ///   - theme: plays this theme once instead of the profile's own (Library tab).
    ///   - briefingOnly: skips the chime and the loved-one clip (Today > Today's briefing).
    func playWelcomeSequence(theme: SoundTheme? = nil, briefingOnly: Bool = false, briefing: String? = nil) {
        stopCurrent()
        let profile = SharedStore.loadProfile()
        var ritual = profile?.ritual ?? Ritual()
        if let theme { ritual.theme = theme }
        let lovedOne = profile.map(LovedOneStore.isAvailable) ?? false
        var steps = RitualPlan.steps(ritual: ritual, lovedOneAvailable: lovedOne)
        if briefingOnly { steps = [.briefing] }
        briefingText = briefing ?? BriefingBuilder.build()
        guard activateSession() else { return }
        queue = steps
        Metrics.shared.log(.welcomeStarted, ["theme": briefingOnly ? "none" : ritual.theme.rawValue])
        updateNowPlaying(title: welcomeTitle(), subtitle: "Welcome theme")
        runNext()
    }

    func stop() {
        stopCurrent()
        finish()
    }

    // MARK: - Steps

    private func runNext() {
        guard !queue.isEmpty else { finish(); return }
        switch queue.removeFirst() {
        case .chime(let theme):
            stage = .welcome
            if let url = SoundLibrary.url(for: theme, hour: Calendar.current.component(.hour, from: Date())), play(url) { return }
            chimeFinished()
        case .lovedOne:
            stage = .lovedOne
            if let profile = SharedStore.loadProfile(), let url = LovedOneStore.url(for: profile), play(url) {
                Metrics.shared.log(.lovedOnePlayed, ["label": profile.lovedOne.label])
                return
            }
            runNext()
        case .pause(let seconds):
            let token = runToken
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(seconds) * 1_000_000_000)
                guard let self, self.runToken == token else { return }
                self.runNext()
            }
        case .briefing:
            startBriefing()
        }
    }

    private func play(_ url: URL) -> Bool {
        guard let p = try? AVAudioPlayer(contentsOf: url) else { return false }
        player = p; p.delegate = self
        return p.play()
    }

    private func chimeFinished() {
        Metrics.shared.log(.welcomeFinished)
        runNext()
    }

    private func startBriefing() {
        stage = .briefing
        Metrics.shared.log(.briefingStarted)
        updateNowPlaying(title: "Your drive briefing", subtitle: SharedStore.loadProfile()?.displayName ?? "My Drive")
        let u = AVSpeechUtterance(string: briefingText)
        u.voice = AVSpeechSynthesisVoice(language: "en-IN") ?? AVSpeechSynthesisVoice(language: "en-GB")
        u.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
        speech.speak(u)
    }

    private func stopCurrent() {
        runToken += 1
        queue = []
        player?.stop(); player = nil
        speech.stopSpeaking(at: .immediate)
    }

    private func finish() {
        guard stage != .idle else { return }
        stage = .done
        Metrics.shared.log(.briefingFinished)
        // Release the session with notifyOthers so the user's music app resumes.
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        Metrics.shared.log(.handoffMusic)
        stage = .idle
    }

    private func activateSession() -> Bool {
        let s = AVAudioSession.sharedInstance()
        do {
            try s.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try s.setActive(true)
            return true
        } catch {
            Metrics.shared.log(.error, ["where": "audio_session", "msg": error.localizedDescription])
            return false
        }
    }

    private func welcomeTitle() -> String {
        let name = SharedStore.loadProfile()?.ownerName ?? ""
        return name.isEmpty ? "Welcome back" : "Welcome back, \(name)"
    }

    // MARK: - Now playing (what CarPlay / lock screen show)

    private func updateNowPlaying(title: String, subtitle: String) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: subtitle,
            MPNowPlayingInfoPropertyPlaybackRate: 1.0,
        ]
        if let profile = SharedStore.loadProfile() {
            let art = ArtworkComposer.compose(profile: profile, line1: "Welcome back,", line2: profile.ownerName)
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: art.size) { _ in art }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func setupRemoteCommands() {
        let c = MPRemoteCommandCenter.shared()
        c.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.player?.pause(); self?.speech.pauseSpeaking(at: .word) }
            return .success
        }
        c.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.player?.play(); self?.speech.continueSpeaking() }
            return .success
        }
        c.stopCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.stop() }
            return .success
        }
    }
}

extension DriveAudioEngine: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            if self.stage == .welcome { self.chimeFinished() } else { self.runNext() }
        }
    }
}

extension DriveAudioEngine: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) {
        Task { @MainActor in self.runNext() }
    }
}
