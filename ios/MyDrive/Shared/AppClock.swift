import Foundation

/// The app's notion of "now". UI tests pin it (launch argument `-uitest-hour`) to test time-of-day behaviour deterministically.
enum AppClock {
    static var override: Date?
    static var now: Date { override ?? Date() }
}
