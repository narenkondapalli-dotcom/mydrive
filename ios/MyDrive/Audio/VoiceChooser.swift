import AVFoundation
import Foundation

/// A speech voice reduced to what ranking needs, so the ranking can be unit tested without the system voice list.
struct VoiceInfo: Equatable, Codable {
    var identifier: String
    var name: String
    var language: String      // BCP-47, e.g. "en-IN"
    var quality: Int          // 1 default, 2 enhanced, 3 premium

    var qualityName: String { ["?", "default", "enhanced", "premium"][min(max(quality, 0), 3)] }
}

/// Picks the best on-device English voice instead of whatever `AVSpeechSynthesisVoice(language:)` returns.
enum VoiceChooser {
    /// Novelty and robotic voices (macOS legacy set, Eloquence) that must never read a briefing.
    static let noveltyNames: Set<String> = [
        "fred", "albert", "zarvox", "bad news", "bells", "boing", "bubbles", "cellos", "deranged", "good news", "hysterical",
        "jester", "organ", "superstar", "trinoids", "whisper", "wobble", "junior", "kathy", "princess", "ralph", "bahh",
        "eddy", "flo", "grandma", "grandpa", "reed", "rocko", "sandy", "shelley",
    ]

    /// Established voices preferred, in order (male or neutral sounding).
    static let preferredNames = ["rishi", "daniel", "arthur", "oliver", "aaron", "gordon"]
    static let languageOrder = ["en-IN", "en-GB", "en-AU", "en-US"]

    static func isNovelty(_ v: VoiceInfo) -> Bool {
        let id = v.identifier.lowercased()
        return id.contains("eloquence") || id.hasPrefix("com.apple.speech.synthesis.voice.") || noveltyNames.contains(v.name.lowercased())
    }

    static func languageRank(_ lang: String) -> Int {
        let l = lang.replacingOccurrences(of: "_", with: "-")
        return languageOrder.firstIndex(of: l) ?? languageOrder.count
    }

    /// English voices without novelty ones, best first: quality, then established name, then language preference.
    static func rank(_ voices: [VoiceInfo]) -> [VoiceInfo] {
        let usable = voices.filter { $0.language.lowercased().hasPrefix("en") && !isNovelty($0) }
        func key(_ v: VoiceInfo) -> [String] {
            let n = preferredNames.firstIndex(of: v.name.lowercased()) ?? preferredNames.count
            return [String(3 - v.quality), String(n), String(languageRank(v.language)), v.identifier]
        }
        return usable.sorted { a, b in
            let ka = key(a), kb = key(b)
            for i in 0..<3 where ka[i] != kb[i] { return Int(ka[i])! < Int(kb[i])! }
            return ka[3] < kb[3]
        }
    }

    static func choose(from voices: [VoiceInfo]) -> VoiceInfo? { rank(voices).first }

    static func systemVoices() -> [VoiceInfo] {
        AVSpeechSynthesisVoice.speechVoices().map {
            VoiceInfo(identifier: $0.identifier, name: $0.name, language: $0.language, quality: $0.quality.rawValue)
        }
    }

    /// The chosen voice and the full ranked list (for diagnostics).
    static func current() -> (chosen: VoiceInfo?, ranked: [VoiceInfo]) {
        let r = rank(systemVoices())
        return (r.first, r)
    }

    static let upgradeHint = "This voice is basic quality. For a better one: iPhone Settings > Accessibility > Spoken Content > Voices > English, then download an Enhanced or Premium voice."

    /// Hint text if the best available voice is only default quality; nil otherwise.
    static func hint(for chosen: VoiceInfo?) -> String? {
        guard let chosen, chosen.quality >= 2 else { return upgradeHint }
        return nil
    }

    // Speaking style.
    static let rate: Float = 0.49
    static let pitch: Float = 0.96
}
