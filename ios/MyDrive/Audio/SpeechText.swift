import AVFoundation
import Foundation

/// Makes briefing text sound right when an on-device voice reads it: spoken numbers, units, dashes,
/// and pronunciation of car makes and models the voices get wrong.
/// All spoken briefing text goes through `normalise`, and `utterance` adds IPA overrides.
enum SpeechText {
    // MARK: Numbers

    private static let ones = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven",
                               "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen"]
    private static let tens = ["", "", "twenty", "thirty", "forty", "fifty"]

    /// 0...59 in words.
    static func words(_ n: Int) -> String {
        if n < 20 { return ones[max(n, 0)] }
        let t = tens[min(n / 10, 5)], r = n % 10
        return r == 0 ? t : "\(t) \(ones[r])"
    }

    /// "9:30" -> "nine thirty", "9:05" -> "nine oh five", "9:00" -> "nine o'clock".
    static func spokenTime(hour: Int, minute: Int) -> String {
        let h = hour % 24
        let h12 = h % 12 == 0 ? 12 : h % 12
        switch minute {
        case 0: return "\(words(h12)) o'clock"
        case 1...9: return "\(words(h12)) oh \(words(minute))"
        default: return "\(words(h12)) \(words(minute))"
        }
    }

    private static let ordinalWords: [Int: String] = [
        1: "first", 2: "second", 3: "third", 4: "fourth", 5: "fifth", 6: "sixth", 7: "seventh", 8: "eighth", 9: "ninth",
        10: "tenth", 11: "eleventh", 12: "twelfth", 13: "thirteenth", 14: "fourteenth", 15: "fifteenth", 16: "sixteenth",
        17: "seventeenth", 18: "eighteenth", 19: "nineteenth", 20: "twentieth", 21: "twenty first", 22: "twenty second",
        23: "twenty third", 24: "twenty fourth", 25: "twenty fifth", 26: "twenty sixth", 27: "twenty seventh",
        28: "twenty eighth", 29: "twenty ninth", 30: "thirtieth", 31: "thirty first",
    ]

    // MARK: Car names

    /// Plain-text respellings applied before anything else (letter codes read out letter by letter, odd spellings).
    /// Order matters: longer names first.
    static let respellings: [(String, String)] = [
        ("Mercedes-Benz", "Mercedes Benz"), ("XUV700", "X U V seven hundred"), ("XEV 9e", "X E V nine E"),
        ("BE 6", "B E six"), ("Scorpio-N", "Scorpio N"), ("C-Class", "C Class"), ("Windsor EV", "Windsor E V"),
        ("Hyryder", "Hi rider"), ("Hycross", "Hi cross"), ("Roxx", "Rocks"), ("Dzire", "Desire"), ("Curvv", "Curve"),
        ("BMW", "B M W"), ("GLA", "G L A"), ("X1", "X one"), ("Q3", "Q three"), ("SUV", "S U V"),
        ("MG", "M G"), ("EV", "E V"),
    ]

    /// IPA for names the default voices tend to get wrong. Only names confidently known; others are left plain.
    static let ipaOverrides: [(word: String, ipa: String)] = [
        ("Meridian", "məˈrɪdiən"), ("Fortuner", "fɔːrˈtuːnər"), ("Safari", "səˈfɑːri"), ("Creta", "ˈkreɪtɑː"),
        ("Nexon", "ˈnɛksɒn"), ("Thar", "tɑːr"), ("Innova", "ɪˈnoʊvɑː"), ("Taigun", "ˈtaɪɡuːn"), ("Slavia", "ˈslɑːviə"),
        ("Brezza", "ˈbrɛzɑː"), ("Baleno", "bəˈleɪnoʊ"), ("Ertiga", "ɜːrˈtiːɡɑː"), ("Vitara", "vɪˈtɑːrɑː"),
        ("Alcazar", "ælˈkɑːzɑːr"), ("Hyundai", "ˈhʌndeɪ"), ("Mahindra", "məˈhɪndrɑː"), ("Maruti", "məˈruːti"),
        ("Tata", "ˈtɑːtɑː"),
    ]

    // MARK: Normaliser

    static func normalise(_ input: String) -> String {
        var s = input
        for (from, to) in respellings { s = s.replacingOccurrences(of: from, with: to) }
        s = s.replacingOccurrences(of: "&", with: " and ")

        // 9:30 -> nine thirty (optionally followed by am / pm)
        s = replace(s, pattern: #"\b(\d{1,2}):(\d{2})\s*([ap])\.?m\.?"#) { m in
            guard let h = Int(m[1]), let mi = Int(m[2]) else { return m[0] }
            return spokenTime(hour: h, minute: mi) + " " + (m[3].lowercased() == "a" ? "A M" : "P M")
        }
        s = replace(s, pattern: #"\b(\d{1,2}):(\d{2})\b"#) { m in
            guard let h = Int(m[1]), let mi = Int(m[2]), h < 24, mi < 60 else { return m[0] }
            return spokenTime(hour: h, minute: mi)
        }
        // 32 min -> 32 minutes
        s = replace(s, pattern: #"\b(\d+)\s*(?:mins|min)\b"#) { m in
            m[1] == "1" ? "1 minute" : "\(m[1]) minutes"
        }
        // km -> kilometres
        s = replace(s, pattern: #"(\d(?:\.\d+)?)\s*km\b"#) { m in
            m[1] == "1" ? "1 kilometre" : "\(m[1]) kilometres"
        }
        s = replace(s, pattern: #"\bkm\b"#) { _ in "kilometres" }
        // 3rd -> third
        s = replace(s, pattern: #"\b(\d{1,2})(?:st|nd|rd|th)\b"#) { m in
            Int(m[1]).flatMap { ordinalWords[$0] } ?? m[0]
        }
        // Dashes become pauses (commas); hyphens inside a word become spaces.
        s = replace(s, pattern: #"\s*[—–]\s*"#) { _ in ", " }
        s = replace(s, pattern: #"\s+-\s+"#) { _ in ", " }
        s = replace(s, pattern: #"(?<=\p{L})-(?=\p{L})"#) { _ in " " }
        s = replace(s, pattern: #",\s*,"#) { _ in "," }
        s = replace(s, pattern: #"\s{2,}"#) { _ in " " }
        s = replace(s, pattern: #"\s+([,.;!?])"#) { m in m[1] }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: IPA

    struct IPAHit: Equatable { var word: String; var ipa: String; var range: NSRange }

    /// Where IPA overrides apply in an already-normalised string.
    static func ipaHits(in s: String) -> [IPAHit] {
        let ns = s as NSString
        var hits: [IPAHit] = []
        for (word, ipa) in ipaOverrides {
            guard let re = try? NSRegularExpression(pattern: "\\b\(NSRegularExpression.escapedPattern(for: word))\\b", options: [.caseInsensitive]) else { continue }
            for m in re.matches(in: s, range: NSRange(location: 0, length: ns.length)) {
                hits.append(IPAHit(word: ns.substring(with: m.range), ipa: ipa, range: m.range))
            }
        }
        return hits
    }

    /// Utterance for already-normalised text, with IPA notation on names that need it.
    static func utterance(for normalised: String) -> (utterance: AVSpeechUtterance, hits: [IPAHit]) {
        let hits = ipaHits(in: normalised)
        if hits.isEmpty { return (AVSpeechUtterance(string: normalised), []) }
        let attr = NSMutableAttributedString(string: normalised)
        let key = NSAttributedString.Key(rawValue: AVSpeechSynthesisIPANotationAttribute)
        for h in hits { attr.addAttribute(key, value: h.ipa, range: h.range) }
        return (AVSpeechUtterance(attributedString: attr), hits)
    }

    // MARK: Regex helper

    private static func replace(_ s: String, pattern: String, _ transform: ([String]) -> String) -> String {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return s }
        let ns = s as NSString
        var out = "", last = 0
        for m in re.matches(in: s, range: NSRange(location: 0, length: ns.length)) {
            out += ns.substring(with: NSRange(location: last, length: m.range.location - last))
            let groups = (0..<m.numberOfRanges).map { i -> String in
                let r = m.range(at: i)
                return r.location == NSNotFound ? "" : ns.substring(with: r)
            }
            out += transform(groups)
            last = m.range.location + m.range.length
        }
        out += ns.substring(from: last)
        return out
    }
}
