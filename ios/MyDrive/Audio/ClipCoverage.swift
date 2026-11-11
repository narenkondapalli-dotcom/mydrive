import Foundation

/// What a bundled welcome clip already says, so the spoken briefing that follows does not repeat it.
/// Source: the actual clip texts (shared/sounds/welcome/README.md).
struct ClipCoverage: Equatable {
    var greeting: Bool      // a time-of-day hello ("Good evening", "Hello again")
    var ready: Bool         // "all systems online and ready"
    var safeClosing: Bool   // "drive safe", "let's have a good drive", "get you home safely"
    var text: String

    static let none = ClipCoverage(greeting: false, ready: false, safeClosing: false, text: "")

    static func of(theme: SoundTheme, period: DayPeriod) -> ClipCoverage {
        switch (theme, period) {
        case (.jarvis, .morning):   return .init(greeting: true, ready: true, safeClosing: false, text: "Good morning, sir. All systems online and ready.")
        case (.jarvis, .afternoon): return .init(greeting: true, ready: true, safeClosing: false, text: "Good afternoon, sir. All systems online and ready.")
        case (.jarvis, .evening):   return .init(greeting: true, ready: true, safeClosing: false, text: "Good evening, sir. All systems online and ready.")
        case (.jarvis, .night):     return .init(greeting: true, ready: true, safeClosing: true, text: "Good evening, sir. All systems online. Do drive safely.")
        case (.warm, .morning):     return .init(greeting: true, ready: false, safeClosing: true, text: "Good morning! Lovely to see you. Let's have a good drive.")
        case (.warm, .afternoon):   return .init(greeting: true, ready: false, safeClosing: true, text: "Good afternoon! Good to have you back. Let's have a good drive.")
        case (.warm, .evening):     return .init(greeting: true, ready: false, safeClosing: true, text: "Good evening! Welcome back. Let's get you home safely.")
        case (.warm, .night):       return .init(greeting: true, ready: false, safeClosing: true, text: "Hello again. It's late, so take it easy. Drive safe.")
        case (.minimal, .morning):   return .init(greeting: true, ready: false, safeClosing: false, text: "Good morning.")
        case (.minimal, .afternoon): return .init(greeting: true, ready: false, safeClosing: false, text: "Good afternoon.")
        case (.minimal, .evening):   return .init(greeting: true, ready: false, safeClosing: false, text: "Good evening.")
        case (.minimal, .night):     return .init(greeting: true, ready: false, safeClosing: true, text: "Good night. Drive safe.")
        }
    }
}
