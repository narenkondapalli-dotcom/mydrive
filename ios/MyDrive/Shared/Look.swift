import Foundation

/// P5: accent colour that follows the car's paint.
enum Accent {
    static let fallbackHex = "#D4B97E"   // gold

    private static let table: [(words: Set<String>, hex: String)] = [
        (["blue", "navy", "indigo", "cobalt"], "#5B9BD5"),
        (["red", "maroon", "burgundy", "wine", "crimson"], "#D9534F"),
        (["green", "olive", "emerald", "forest"], "#5FAF7A"),
        (["orange", "copper", "rust"], "#E0894A"),
        (["yellow", "amber"], "#E3C14E"),
        (["brown", "bronze", "beige", "tan", "coffee", "mocha"], "#B8895A"),
        (["purple", "violet", "plum"], "#9A7CCF"),
    ]

    /// Maps a paint name ("Galaxy Blue") to an accent. Neutral paints (white, silver, grey, black) and unknown names use gold.
    static func hex(forPaint name: String) -> String {
        let words = Set(name.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init))
        return table.first(where: { !$0.words.isDisjoint(with: words) })?.hex ?? fallbackHex
    }
}

enum TimeOfDay: String, CaseIterable { case dawn, day, dusk, night }
enum Season: String, CaseIterable { case summer, monsoon, winter }

/// P5: scene drawn behind the car in the now-playing artwork. Seasons are northern-India:
/// summer Mar-Jun, monsoon Jul-Sep, winter Oct-Feb.
struct ArtworkScene: Equatable {
    var timeOfDay: TimeOfDay
    var season: Season

    static func pick(date: Date = Date(), calendar: Calendar = .current) -> ArtworkScene {
        let hour = calendar.component(.hour, from: date)
        let month = calendar.component(.month, from: date)
        let tod: TimeOfDay
        switch hour {
        case 5..<8: tod = .dawn
        case 8..<17: tod = .day
        case 17..<20: tod = .dusk
        default: tod = .night
        }
        let season: Season
        switch month {
        case 3...6: season = .summer
        case 7...9: season = .monsoon
        default: season = .winter
        }
        return ArtworkScene(timeOfDay: tod, season: season)
    }

    var topHex: String {
        switch timeOfDay {
        case .dawn: return "#F2B58A"
        case .day: return "#3C5A78"
        case .dusk: return "#C0563B"
        case .night: return "#07090F"
        }
    }

    var bottomHex: String {
        switch timeOfDay {
        case .dawn: return "#3B3A55"
        case .day: return "#8FB3CF"
        case .dusk: return "#2A2147"
        case .night: return "#141B2D"
        }
    }

    var tintHex: String {
        switch season {
        case .summer: return "#E8A33D"
        case .monsoon: return "#4F7F78"
        case .winter: return "#8FA8C8"
        }
    }
}

/// Welcome clips are recorded per period; hours match shared/briefing/greetings.json.
enum DayPeriod: String, CaseIterable {
    case morning, afternoon, evening, night

    static func at(hour: Int) -> DayPeriod {
        switch hour {
        case 5...11: return .morning
        case 12...16: return .afternoon
        case 17...20: return .evening
        default: return .night
        }
    }
}
