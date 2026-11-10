import AVFoundation
import MediaPlayer
import UIKit

/// Plays the welcome theme, then the spoken briefing, then hands off to the user's music.
/// Audio session is activated only at the moment sound starts (CarPlay rule: never at launch).
@MainActor
final class DriveAudioEngine: NSObject, ObservableObject {
    static let shared = DriveAudioEngine()

    enum Stage: String { case idle, welcome, briefing, done }
    @Published private(set) var stage: Stage = .idle

    private var player: AVAudioPlayer?
    private let speech = AVSpeechSynthesizer()
    private var briefingText = ""

    override init() {
        super.init()
        speech.delegate = self
        setupRemoteCommands()
    }

    /// Entry point used by CarPlay "Today", the Shortcut intent and the Android-equivalent fake connect.
    func playWelcomeSequence(theme: String = "signature", briefing: String) {
        briefingText = briefing
        guard activateSession() else { return }
        stage = .welcome
        Metrics.shared.log(.welcomeStarted, ["theme": theme])
        updateNowPlaying(title: welcomeTitle(), subtitle: "Welcome theme")
        if let url = Bundle.main.url(forResource: "welcome-\(theme)", withExtension: "m4a"),
           let p = try? AVAudioPlayer(contentsOf: url) {
            player = p; p.delegate = self; p.play()
        } else {
            // No sound bundled yet: go straight to the briefing.
            startBriefing()
        }
    }

    func stop() {
        player?.stop(); speech.stopSpeaking(at: .immediate)
        finish()
    }

    // MARK: - Steps

    private func startBriefing() {
        stage = .briefing
        Metrics.shared.log(.welcomeFinished)
        Metrics.shared.log(.briefingStarted)
        updateNowPlaying(title: "Your drive briefing", subtitle: SharedStore.loadProfile()?.displayName ?? "My Drive")
        let u = AVSpeechUtterance(string: briefingText)
        u.voice = AVSpeechSynthesisVoice(language: "en-IN") ?? AVSpeechSynthesisVoice(language: "en-GB")
        u.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
        speech.speak(u)
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
        Task { @MainActor in self.startBriefing() }
    }
}

extension DriveAudioEngine: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) {
        Task { @MainActor in self.finish() }
    }
}
