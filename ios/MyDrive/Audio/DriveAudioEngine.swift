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

/// Plays the active profile's ritual as ONE continuous sequence: chime, optional loved-one clip, optional pause, spoken briefing,
/// then hands back to the user's music. One audio session, one Now Playing item.
///
/// The briefing is rendered to audio (AVSpeechSynthesizer.write) while the clip plays and is queued on the same AVAudioEngine
/// with a host-time start equal to the clip's end, so there is no audible gap. If rendering fails the engine falls back to
/// live speech; if the audio engine cannot start (no audio hardware, e.g. CI) the timeline runs on timers ("virtual" mode).
/// The audio session is activated only when sound is about to start (CarPlay rule: never at launch).
@MainActor
final class DriveAudioEngine: NSObject, ObservableObject {
    static let shared = DriveAudioEngine()

    enum Stage: String { case idle, welcome, lovedOne, briefing, done }
    @Published private(set) var stage: Stage = .idle
    @Published private(set) var voice: VoiceInfo?

    private let engine = AVAudioEngine()
    private var nodes: [AVAudioPlayerNode] = []
    private var finishedNames = Set<String>()
    private var runToken = 0
    private var running = false
    private var sequenceTask: Task<Void, Never>?
    private var currentSurface = ""
    private var lastStart = Date.distantPast
    private var warmed = false

    private var live: AVSpeechSynthesizer?
    private var liveFinished = false
    private var liveStartedAt: Date?
    private var sequenceBegan = Date()

    override init() {
        super.init()
        setupRemoteCommands()
    }

    // MARK: - Warm-up

    /// Prepares everything that is slow on a cold start, before any session is activated: audio graph, voice list,
    /// the chime file, and the speech synthesizer (one silent throw-away render). Logs how long it took.
    func prewarm() {
        guard !warmed else { return }
        warmed = true
        let t0 = Date()
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])   // category only, not activated
        _ = engine.mainMixerNode
        engine.prepare()
        let chosen = VoiceChooser.current()
        voice = chosen.chosen
        let hour = Calendar.current.component(.hour, from: AppClock.now)
        if let url = SoundLibrary.url(for: SharedStore.loadProfile()?.ritual.theme ?? .jarvis, hour: hour),
           let f = try? AVAudioFile(forReading: url) { _ = f.length }
        let setupMs = Int(Date().timeIntervalSince(t0) * 1000)
        Task {
            let r = await SpeechRenderer.render(PreparedSpeech.make("Ready."), timeout: 6)
            Diagnostics.shared.log("warmup", ["setup_ms": setupMs, "synth_ms": r.renderMs,
                                              "synth_ok": r.isUsable, "voice": chosen.chosen?.name ?? "none",
                                              "voices_ranked": chosen.ranked.count])
        }
    }

    // MARK: - Entry point

    /// Used by CarPlay "Today", the Shortcut intent and the debug fake connect.
    /// - Parameters:
    ///   - theme: plays this theme once instead of the profile's own (Library tab).
    ///   - briefingOnly: skips the chime and the loved-one clip (Today > Today's briefing); the briefing then has a full greeting.
    ///   - surface: who asked ("phone", "carplay", "shortcut", "debug"). A repeat from the same surface while its sequence
    ///     is still running is a duplicate and is ignored (restart is allowed once it finished); a different surface interrupts it.
    func playWelcomeSequence(theme: SoundTheme? = nil, briefingOnly: Bool = false, briefing: String? = nil,
                             surface: String = "phone") {
        let now = Date()
        let diag = Diagnostics.shared
        if surface == currentSurface, running {
            diag.log("duplicate_ignored", ["surface": surface, "since_last_start_ms": Int(now.timeIntervalSince(lastStart) * 1000), "running": running])
            Metrics.shared.log(.duplicateIgnored, ["surface": surface])
            return
        }
        if running { interrupt(reason: "new_start_from_\(surface)", deactivate: false) }
        runToken += 1
        let token = runToken
        currentSurface = surface
        lastStart = now
        sequenceBegan = now

        let profile = SharedStore.loadProfile()
        var ritual = profile?.ritual ?? Ritual()
        if let theme { ritual.theme = theme }
        let lovedOne = profile.map(LovedOneStore.isAvailable) ?? false
        var steps = RitualPlan.steps(ritual: ritual, lovedOneAvailable: lovedOne)
        if briefingOnly { steps = [.briefing] }

        let clockNow = AppClock.now
        let hour = Calendar.current.component(.hour, from: clockNow)
        let period = DayPeriod.at(hour: hour)
        var chimeURL: URL?
        if steps.contains(where: { if case .chime = $0 { return true } else { return false } }) {
            chimeURL = SoundLibrary.url(for: ritual.theme, hour: hour)
        }
        let coverage = chimeURL != nil ? ClipCoverage.of(theme: ritual.theme, period: period) : .none
        let text = briefing ?? BriefingBuilder.build(now: clockNow, clip: coverage)
        let prepared: PreparedSpeech? = steps.contains(.briefing) ? PreparedSpeech.make(text) : nil
        let ranked = VoiceChooser.current()
        voice = ranked.chosen

        diag.log("sequence_started", ["surface": surface, "theme": briefingOnly ? "none" : ritual.theme.rawValue,
                                      "period": period.rawValue, "hour": hour, "briefing_only": briefingOnly,
                                      "steps": "\(steps)", "clip": chimeURL?.lastPathComponent ?? "none",
                                      "clip_covers": "greeting=\(coverage.greeting) ready=\(coverage.ready) closing=\(coverage.safeClosing)"])
        if let prepared {
            diag.log("utterance", ["raw": prepared.raw, "normalised": prepared.normalised, "ipa": prepared.ipaWords,
                                   "voice_id": prepared.voice?.identifier ?? "none", "voice_name": prepared.voice?.name ?? "none",
                                   "voice_quality": prepared.voice?.qualityName ?? "none", "voice_lang": prepared.voice?.language ?? "none",
                                   "rate": VoiceChooser.rate, "pitch": VoiceChooser.pitch])
            diag.log("voices_ranked", ["list": ranked.ranked.prefix(12).map { "\($0.name)|\($0.language)|\($0.qualityName)|\($0.identifier)" }])
        }
        Metrics.shared.log(.welcomeStarted, ["theme": briefingOnly ? "none" : ritual.theme.rawValue, "surface": surface])

        _ = activateSession()   // on failure it is logged; the sequence still runs (virtual timeline) so stages stay observable
        running = true
        stage = briefingOnly ? .briefing : .welcome
        updateNowPlaying()
        sequenceTask = Task { [weak self] in
            await self?.run(token: token, steps: steps, chimeURL: chimeURL, prepared: prepared)
        }
    }

    /// Explicit stop (remote command, stop button).
    func stop() {
        if running { interrupt(reason: "stop", deactivate: true) }
    }

    // MARK: - The sequence

    private struct FileSegment {
        let url: URL
        let file: AVAudioFile
        let stage: Stage
        let start: Double
        let duration: Double
    }

    private func alive(_ token: Int) -> Bool { token == runToken && !Task.isCancelled }
    private func hostTicks(_ seconds: Double) -> UInt64 { AVAudioTime.hostTime(forSeconds: max(seconds, 0)) }
    private func ms(_ seconds: Double) -> Int { Int((seconds * 1000).rounded()) }

    private func run(token: Int, steps: [RitualStep], chimeURL: URL?, prepared: PreparedSpeech?) async {
        let diag = Diagnostics.shared
        let renderTask: Task<RenderedSpeech, Never>? = prepared.map { p in Task { await SpeechRenderer.render(p) } }

        // 1. Plan the timeline. Durations of the files are known up front.
        var segments: [FileSegment] = []
        var cursor = 0.0
        var speechStart: Double?
        for step in steps {
            switch step {
            case .chime:
                if let url = chimeURL, let f = try? AVAudioFile(forReading: url) {
                    let d = Double(f.length) / f.processingFormat.sampleRate
                    segments.append(FileSegment(url: url, file: f, stage: .welcome, start: cursor, duration: d))
                    cursor += d
                }
            case .lovedOne:
                if let p = SharedStore.loadProfile(), let url = LovedOneStore.url(for: p), let f = try? AVAudioFile(forReading: url) {
                    let d = Double(f.length) / f.processingFormat.sampleRate
                    segments.append(FileSegment(url: url, file: f, stage: .lovedOne, start: cursor, duration: d))
                    cursor += d
                    Metrics.shared.log(.lovedOnePlayed, ["label": p.lovedOne.label])
                }
            case .pause(let s):
                cursor += Double(s)
            case .briefing:
                speechStart = cursor
            }
        }
        let clipsEnd = segments.last.map { $0.start + $0.duration }

        // 2. Schedule the clips and start the engine.
        finishedNames = []
        var planned: [(FileSegment, AVAudioPlayerNode)] = []
        for seg in segments {
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: seg.file.processingFormat)
            nodes.append(node)
            let name = seg.url.lastPathComponent
            node.scheduleFile(seg.file, at: nil, completionCallbackType: .dataPlayedBack) { [weak self] _ in
                Task { @MainActor in self?.nodeDone(name, token: token) }
            }
            planned.append((seg, node))
        }
        let engineStart = Date()
        var hardware = true
        do {
            try engine.start()
        } catch {
            hardware = false
            diag.log("engine_unavailable", ["error": error.localizedDescription, "mode": "virtual timeline"])
            Metrics.shared.log(.error, ["where": "audio_engine", "msg": error.localizedDescription])
        }
        let leadIn = 0.12
        let baseHost = mach_absolute_time() + hostTicks(leadIn)
        let baseWall = Date().addingTimeInterval(leadIn)
        if hardware { for (seg, node) in planned { node.play(at: AVAudioTime(hostTime: baseHost + hostTicks(seg.start))) } }
        diag.log("audio_ready", ["engine_start_ms": ms(Date().timeIntervalSince(engineStart)), "hardware": hardware,
                                 "since_sequence_start_ms": ms(Date().timeIntervalSince(sequenceBegan)),
                                 "clips": segments.map { $0.url.lastPathComponent }])

        // 3. Queue the speech right behind the clip (same node graph, host-time start = clip end).
        var speechMode = "none"
        var speechStartRel: Double?
        var speechEndRel: Double?
        var needsLive = false
        if let renderTask, let ss = speechStart {
            let rendered = await renderTask.value
            guard alive(token) else { return }
            diag.log("speech_rendered", ["render_ms": rendered.renderMs, "duration_s": (rendered.duration * 100).rounded() / 100,
                                         "frames": rendered.frames, "sample_rate": rendered.format?.sampleRate ?? 0,
                                         "error": rendered.error ?? "none"])
            if rendered.isUsable, let fmt = rendered.format {
                speechMode = hardware ? "engine" : "virtual"
                var lateness = 0.0
                if hardware {
                    let node = AVAudioPlayerNode()
                    engine.attach(node)
                    engine.connect(node, to: engine.mainMixerNode, format: fmt)
                    nodes.append(node)
                    for (i, b) in rendered.buffers.enumerated() {
                        if i == rendered.buffers.count - 1 {
                            node.scheduleBuffer(b, at: nil, options: [], completionCallbackType: .dataPlayedBack) { [weak self] _ in
                                Task { @MainActor in self?.nodeDone("speech", token: token) }
                            }
                        } else {
                            node.scheduleBuffer(b, completionHandler: nil)
                        }
                    }
                    let plannedHost = baseHost + hostTicks(ss)
                    let nowHost = mach_absolute_time()
                    let startHost = max(plannedHost, nowHost + hostTicks(0.02))
                    lateness = AVAudioTime.seconds(forHostTime: startHost - plannedHost)
                    node.play(at: AVAudioTime(hostTime: startHost))
                }
                speechStartRel = ss + lateness
                speechEndRel = ss + lateness + rendered.duration
                let gapMs = clipsEnd.map { ms(speechStartRel! - $0) }
                diag.log("speech_scheduled", ["mode": speechMode, "gap_ms": gapMs ?? -1, "intended_pause_ms": ms(ss - (clipsEnd ?? ss)),
                                              "lateness_ms": ms(lateness), "clip_end_s": clipsEnd ?? -1, "speech_start_s": speechStartRel!])
            } else {
                speechMode = "live_fallback"
                needsLive = true
                speechStartRel = ss
                diag.log("speech_fallback", ["reason": rendered.error ?? "no buffers rendered"])
            }
        }

        // 4. Timeline driver: stage changes and events until everything has finished.
        var expected = Set(segments.map { $0.url.lastPathComponent })
        if speechMode == "engine" || speechMode == "virtual" { expected.insert("speech") }
        let clipNames = Set(segments.map { $0.url.lastPathComponent })
        var stageNow = stage
        var started = Set<String>()
        var liveBegan = false
        var welcomeLogged = false
        let hardLimit = (speechEndRel ?? clipsEnd ?? 1) + (needsLive ? 30 : 4)
        while alive(token) {
            let el = Date().timeIntervalSince(baseWall)
            for seg in segments where el >= seg.start && !started.contains(seg.url.lastPathComponent) {
                started.insert(seg.url.lastPathComponent)
                diag.log("clip_started", ["file": seg.url.lastPathComponent, "planned_ms": ms(seg.start), "at_ms": ms(el),
                                          "duration_ms": ms(seg.duration)])
                if !hardware { Task { @MainActor in
                    try? await Task.sleep(nanoseconds: UInt64(seg.duration * 1_000_000_000))
                    self.nodeDone(seg.url.lastPathComponent, token: token)
                } }
            }
            if !welcomeLogged, el >= (segments.first.map { $0.start + $0.duration } ?? 0) {
                welcomeLogged = true
                diag.log("welcome_finished", ["at_ms": ms(el)])
                Metrics.shared.log(.welcomeFinished)
            }
            if let s = speechStartRel, el >= s, !started.contains("speech") {
                if needsLive {
                    if clipNames.isSubset(of: finishedNames) && !liveBegan {
                        liveBegan = true
                        started.insert("speech")
                        speakLive(prepared!)
                    }
                } else {
                    started.insert("speech")
                    diag.log("speech_started", ["mode": speechMode, "at_ms": ms(el), "planned_ms": ms(s)])
                    Metrics.shared.log(.briefingStarted)
                    if !hardware, let e = speechEndRel {
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: UInt64(max(e - s, 0) * 1_000_000_000))
                            self.nodeDone("speech", token: token)
                        }
                    }
                }
            }
            var want = stageNow
            for seg in segments where el >= seg.start { want = seg.stage }
            if let s = speechStartRel, el >= s { want = .briefing }
            if want != stageNow {
                diag.log("stage", ["from": stageNow.rawValue, "to": want.rawValue, "at_ms": ms(el)])
                stageNow = want
                stage = want
            }
            if expected.isSubset(of: finishedNames) && (!needsLive || liveFinished) && el > 0.05 { break }
            if el > hardLimit {
                diag.log("completion_timeout", ["el_ms": ms(el), "finished": finishedNames.sorted()])
                break
            }
            try? await Task.sleep(nanoseconds: 30_000_000)
        }
        guard alive(token) else { return }
        finish(token: token)
    }

    private func nodeDone(_ name: String, token: Int) {
        guard token == runToken, running else { return }
        finishedNames.insert(name)
        let ms = Int(Date().timeIntervalSince(sequenceBegan) * 1000)
        if name == "speech" {
            Diagnostics.shared.log("speech_finished", ["since_sequence_start_ms": ms])
            Metrics.shared.log(.briefingFinished)
        } else {
            Diagnostics.shared.log("clip_finished", ["file": name, "since_sequence_start_ms": ms])
        }
    }

    private func speakLive(_ prepared: PreparedSpeech) {
        let synth = AVSpeechSynthesizer()
        synth.delegate = self
        live = synth
        liveFinished = false
        liveStartedAt = Date()
        Diagnostics.shared.log("speech_started", ["mode": "live_fallback"])
        Metrics.shared.log(.briefingStarted)
        synth.speak(prepared.utterance)
    }

    private func finish(token: Int) {
        guard token == runToken, running else { return }
        let diag = Diagnostics.shared
        stage = .done
        diag.log("sequence_finished", ["total_ms": Int(Date().timeIntervalSince(sequenceBegan) * 1000)])
        teardown()
        deactivateSession()
        Metrics.shared.log(.handoffMusic)
        running = false
        stage = .idle
    }

    private func interrupt(reason: String, deactivate: Bool) {
        Diagnostics.shared.log("sequence_interrupted", ["reason": reason, "stage": stage.rawValue,
                                                        "at_ms": Int(Date().timeIntervalSince(sequenceBegan) * 1000)])
        Metrics.shared.log(.sequenceInterrupted, ["reason": reason, "stage": stage.rawValue])
        runToken += 1
        sequenceTask?.cancel()
        teardown()
        if deactivate { deactivateSession() }
        running = false
        stage = .idle
    }

    private func teardown() {
        for n in nodes { n.stop(); engine.detach(n) }
        nodes = []
        if engine.isRunning { engine.stop() }
        live?.stopSpeaking(at: .immediate)
        live = nil
    }

    // MARK: - Session

    private func activateSession() -> Bool {
        let t0 = Date()
        let s = AVAudioSession.sharedInstance()
        do {
            try s.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try s.setActive(true)
            Diagnostics.shared.log("session_activated", ["ms": Int(Date().timeIntervalSince(t0) * 1000)])
            return true
        } catch {
            Diagnostics.shared.log("error", ["where": "audio_session", "msg": error.localizedDescription])
            Metrics.shared.log(.error, ["where": "audio_session", "msg": error.localizedDescription])
            return false
        }
    }

    private func deactivateSession() {
        // notifyOthersOnDeactivation so the user's music app resumes.
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        Diagnostics.shared.log("session_deactivated")
    }

    // MARK: - Now playing (what CarPlay / lock screen show). Set once for the whole sequence.

    private func updateNowPlaying() {
        let profile = SharedStore.loadProfile()
        let name = profile?.ownerName ?? ""
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: name.isEmpty ? "Welcome back" : "Welcome back, \(name)",
            MPMediaItemPropertyArtist: profile?.displayName ?? "My Drive",
            MPNowPlayingInfoPropertyPlaybackRate: 1.0,
        ]
        if let profile {
            let art = ArtworkComposer.compose(profile: profile, line1: "Welcome back,", line2: profile.ownerName)
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: art.size) { _ in art }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func setupRemoteCommands() {
        let c = MPRemoteCommandCenter.shared()
        c.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.nodes.forEach { $0.pause() }; self?.live?.pauseSpeaking(at: .word) }
            return .success
        }
        c.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.nodes.forEach { $0.play() }; self?.live?.continueSpeaking() }
            return .success
        }
        c.stopCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.stop() }
            return .success
        }
    }
}

extension DriveAudioEngine: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) {
        Task { @MainActor in
            self.liveFinished = true
            if self.running {
                Diagnostics.shared.log("speech_finished", ["mode": "live_fallback"])
                Metrics.shared.log(.briefingFinished)
            }
        }
    }
}
