import Foundation

/// Items the driver can switch on or off in the spoken briefing (P2).
/// Weather and traffic have no data source in this build; the switch is stored for when they arrive.
enum BriefingItem: String, Codable, CaseIterable, Hashable {
    case weather, calendar, traffic, usualStop, streak

    var title: String {
        switch self {
        case .weather: return "Weather"
        case .calendar: return "First event of the day"
        case .traffic: return "Traffic ETA"
        case .usualStop: return "Usual stop"
        case .streak: return "Driving streak"
        }
    }
}

enum SoundTheme: String, Codable, CaseIterable {
    case jarvis, warm, minimal
    var title: String { rawValue.capitalized }
}

enum WidgetStyle: String, Codable, CaseIterable {
    case carLarge = "car-large", minimal, stats
    var title: String {
        switch self {
        case .carLarge: return "Car"
        case .minimal: return "Minimal"
        case .stats: return "Stats"
        }
    }
}

/// P4: the ritual that plays when the car connects.
struct Ritual: Codable, Equatable {
    static let delayRange = 0...5

    var theme: SoundTheme = .jarvis
    /// Default 0: the clip flows straight into the briefing. (Stored under a new key, so an old stored 1 s default is dropped.)
    private(set) var pauseSeconds: Int = 0
    var voiceOn: Bool = true

    var delaySeconds: Int { pauseSeconds }

    mutating func setDelay(_ seconds: Int) {
        pauseSeconds = min(max(seconds, Self.delayRange.lowerBound), Self.delayRange.upperBound)
    }
}

/// P2: a short clip recorded on the phone and played after the chime.
struct LovedOne: Codable, Equatable {
    static let maxSeconds: TimeInterval = 15
    var label: String = ""
    var fileName: String?
    var enabled: Bool = false
}

enum RitualStep: Equatable {
    case chime(SoundTheme), lovedOne, pause(Int), briefing
}

/// Turns the ritual settings into the ordered steps the audio engine plays.
enum RitualPlan {
    static func steps(ritual: Ritual, lovedOneAvailable: Bool) -> [RitualStep] {
        var steps: [RitualStep] = [.chime(ritual.theme)]
        if lovedOneAvailable { steps.append(.lovedOne) }
        if ritual.voiceOn {
            if ritual.delaySeconds > 0 { steps.append(.pause(ritual.delaySeconds)) }
            steps.append(.briefing)
        }
        return steps
    }
}

/// Tracks the "When CarPlay connects" Shortcut setup helper (I5).
struct ShortcutSetup: Equatable {
    static let steps = [
        "Open the Shortcuts app and tap Automation, then New Automation.",
        "Choose CarPlay, then Connects, then Run Immediately.",
        "Add the action My Drive, then Play welcome.",
        "Save. Next time your car connects, it welcomes you.",
    ]
    static let shortcutsURL = URL(string: "shortcuts://")!

    var completed: Set<Int> = []

    var isComplete: Bool { completed.count == Self.steps.count }

    /// Returns true when the step is now ticked.
    @discardableResult
    mutating func toggle(_ step: Int) -> Bool {
        guard Self.steps.indices.contains(step) else { return false }
        if completed.contains(step) { completed.remove(step); return false }
        completed.insert(step)
        return true
    }
}

/// One car + driver. Several can exist; one is active and feeds the car screen and the widget.
struct CarProfile: Codable, Equatable {
    var make: String
    var model: String
    var colour: String          // body colour name, e.g. "White"
    var roof: String            // "Body" | "Black"
    var wheels: String          // "Silver" | "Black"
    var nickname: String
    var renderId: String?       // file name of the car picture in the App Group container
    var ownerName: String
    var spokenName: String?     // optional respelling for the voice, e.g. "Moe-hit". nil or empty = ownerName
    var id: String = UUID().uuidString
    var ritual = Ritual()
    var briefingItems: Set<BriefingItem> = Set(BriefingItem.allCases)
    var lovedOne = LovedOne()
    var widgetStyle: WidgetStyle = .carLarge
    var greetingIndex: Int?     // nil = rotate automatically
    var shortcutSteps: Set<Int> = []

    /// What the voice says. The screen always shows `ownerName`.
    var nameForSpeech: String {
        let s = (spokenName ?? "").trimmingCharacters(in: .whitespaces)
        return s.isEmpty ? ownerName : s
    }

    var displayName: String { nickname.isEmpty ? model : nickname }
    var accentHex: String { Accent.hex(forPaint: colour) }
}

/// All profiles plus which one is active.
struct ProfileBook: Codable, Equatable {
    var profiles: [CarProfile] = []
    var activeId: String?

    var active: CarProfile? { profiles.first(where: { $0.id == activeId }) ?? profiles.first }

    mutating func upsert(_ profile: CarProfile, activate: Bool = true) {
        if let i = profiles.firstIndex(where: { $0.id == profile.id }) { profiles[i] = profile } else { profiles.append(profile) }
        if activate || activeId == nil { activeId = profile.id }
    }

    /// Returns false if there is no such profile.
    @discardableResult
    mutating func switchTo(_ id: String) -> Bool {
        guard profiles.contains(where: { $0.id == id }) else { return false }
        activeId = id
        return true
    }

    mutating func remove(_ id: String) {
        profiles.removeAll { $0.id == id }
        if activeId == id { activeId = profiles.first?.id }
    }

    mutating func updateActive(_ change: (inout CarProfile) -> Void) {
        guard var p = active else { return }
        change(&p)
        upsert(p, activate: false)
    }
}
