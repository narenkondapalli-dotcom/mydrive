import AVFoundation
import Foundation

/// Text, normalised text, chosen voice and the ready-to-speak utterance for one briefing.
struct PreparedSpeech {
    var raw: String
    var normalised: String
    var voice: VoiceInfo?
    var ipaWords: [String]
    var utterance: AVSpeechUtterance

    static func make(_ raw: String) -> PreparedSpeech {
        let normalised = SpeechText.normalise(raw)
        let (utt, hits) = SpeechText.utterance(for: normalised)
        let chosen = VoiceChooser.current().chosen
        if let chosen, let v = AVSpeechSynthesisVoice(identifier: chosen.identifier) {
            utt.voice = v
        } else {
            utt.voice = AVSpeechSynthesisVoice(language: "en-GB") ?? AVSpeechSynthesisVoice(language: "en-US")
        }
        utt.rate = VoiceChooser.rate
        utt.pitchMultiplier = VoiceChooser.pitch
        utt.volume = 1
        utt.preUtteranceDelay = 0
        utt.postUtteranceDelay = 0
        return PreparedSpeech(raw: raw, normalised: normalised, voice: chosen,
                              ipaWords: hits.map { "\($0.word)=\($0.ipa)" }, utterance: utt)
    }
}

/// Speech rendered offline to PCM buffers (float32, non-interleaved), ready to be queued right after a clip.
struct RenderedSpeech: @unchecked Sendable {
    var buffers: [AVAudioPCMBuffer] = []
    var renderMs = 0
    var error: String?

    var format: AVAudioFormat? { buffers.first?.format }
    var frames: Int { buffers.reduce(0) { $0 + Int($1.frameLength) } }
    var duration: Double { format.map { Double(frames) / $0.sampleRate } ?? 0 }
    var isUsable: Bool { frames > 0 }
}

/// Renders with `AVSpeechSynthesizer.write`, so the same code path serves live playback and the offline audio capture.
enum SpeechRenderer {
    private final class Box: @unchecked Sendable {
        let lock = NSLock()
        var buffers: [AVAudioPCMBuffer] = []
        var done = false
        var cont: CheckedContinuation<RenderedSpeech, Never>?
        let synth = AVSpeechSynthesizer()
        let start = Date()

        func finish(error: String?) {
            lock.lock()
            if done { lock.unlock(); return }
            done = true
            let r = RenderedSpeech(buffers: buffers, renderMs: Int(Date().timeIntervalSince(start) * 1000), error: error)
            let c = cont
            cont = nil
            lock.unlock()
            c?.resume(returning: r)
        }

        func append(_ b: AVAudioPCMBuffer) {
            lock.lock()
            if !done { buffers.append(b) }
            lock.unlock()
        }
    }

    static func render(_ prepared: PreparedSpeech, timeout: TimeInterval = 10) async -> RenderedSpeech {
        let box = Box()
        return await withCheckedContinuation { (cont: CheckedContinuation<RenderedSpeech, Never>) in
            box.lock.lock(); box.cont = cont; box.lock.unlock()
            box.synth.write(prepared.utterance) { buffer in
                guard let pcm = buffer as? AVAudioPCMBuffer else { return }
                if pcm.frameLength == 0 { box.finish(error: nil); return }
                if let std = standardCopy(pcm) { box.append(std) }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { box.finish(error: "timeout") }
        }
    }

    /// Copy into float32 non-interleaved (what the mixer takes), because the synthesizer varies its buffer format.
    static func standardCopy(_ b: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        let n = Int(b.frameLength)
        guard n > 0,
              let target = AVAudioFormat(standardFormatWithSampleRate: b.format.sampleRate, channels: b.format.channelCount),
              let out = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: b.frameLength) else { return nil }
        out.frameLength = b.frameLength
        let ch = Int(b.format.channelCount)
        if let s = b.floatChannelData, let d = out.floatChannelData {
            for c in 0..<ch { d[c].update(from: s[c], count: n) }
            return out
        }
        if let s = b.int16ChannelData, let d = out.floatChannelData {
            for c in 0..<ch { for i in 0..<n { d[c][i] = Float(s[c][i]) / 32768 } }
            return out
        }
        return nil
    }

    /// 16-bit WAV, for the audio capture artifacts.
    static func writeWav(_ r: RenderedSpeech, to url: URL) throws {
        guard let fmt = r.format else {
            throw NSError(domain: "SpeechRenderer", code: 1, userInfo: [NSLocalizedDescriptionKey: "no audio rendered"])
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: fmt.sampleRate, AVNumberOfChannelsKey: fmt.channelCount,
            AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false,
        ]
        let file = try AVAudioFile(forWriting: url, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)
        for b in r.buffers { try file.write(from: b) }
    }
}
