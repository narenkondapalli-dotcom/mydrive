import Foundation

/// One small set of JSON files in the App Group container.
/// File protection = completeUntilFirstUserAuthentication so CarPlay and the widget can read them while the phone is locked.
/// The CarProfile type itself lives in Personalization.swift.
enum SharedStore {
    static let appGroup = "group.com.biolynk.mydrive"

    /// Tests point this at a temp folder so they never touch real data.
    static var containerOverride: URL?

    static var containerURL: URL {
        if let containerOverride { return containerOverride }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }

    private static var bookURL: URL { containerURL.appendingPathComponent("profiles.json") }

    static func loadBook() -> ProfileBook {
        guard let data = try? Data(contentsOf: bookURL),
              let book = try? JSONDecoder().decode(ProfileBook.self, from: data) else { return ProfileBook() }
        return book
    }

    static func saveBook(_ book: ProfileBook) throws {
        try write(try JSONEncoder().encode(book), to: bookURL)
    }

    /// The active profile: what the car screen, the shortcut and the widget use.
    static func loadProfile() -> CarProfile? { loadBook().active }

    /// Adds or updates this profile and makes it the active one.
    static func saveProfile(_ profile: CarProfile) throws {
        var book = loadBook()
        book.upsert(profile)
        try saveBook(book)
    }

    static func write(_ data: Data, to url: URL) throws {
        // The fallback folder (Application Support) may not exist yet on a fresh install or in tests.
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    static func carImageURL(for profile: CarProfile) -> URL? {
        guard let id = profile.renderId else { return nil }
        return containerURL.appendingPathComponent(id)
    }

    /// Short line for the widget and briefing, written by the app after each briefing refresh.
    static var nextUpURL: URL { containerURL.appendingPathComponent("next-up.json") }

    struct NextUp: Codable, Equatable { var title: String; var detail: String; var updated: Date }

    static func loadNextUp() -> NextUp? {
        guard let data = try? Data(contentsOf: nextUpURL) else { return nil }
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        return try? dec.decode(NextUp.self, from: data)
    }

    static func saveNextUp(_ n: NextUp) throws {
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
        try write(try enc.encode(n), to: nextUpURL)
    }
}
