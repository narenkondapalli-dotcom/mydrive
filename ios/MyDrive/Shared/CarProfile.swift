import Foundation

/// The driver's car, chosen once during onboarding. Shared with the widget via the App Group.
struct CarProfile: Codable, Equatable {
    var make: String
    var model: String
    var colour: String          // body colour name, e.g. "White"
    var roof: String            // "Body" | "Black"
    var wheels: String          // "Silver" | "Black"
    var nickname: String
    var renderId: String?       // file name of the car picture in the App Group container
    var ownerName: String

    var displayName: String { nickname.isEmpty ? model : nickname }
}

/// One small JSON file in the App Group container.
/// File protection = completeUntilFirstUserAuthentication so CarPlay and the widget can read it while the phone is locked.
enum SharedStore {
    static let appGroup = "group.com.biolynk.mydrive"

    static var containerURL: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }

    private static var profileURL: URL { containerURL.appendingPathComponent("car-profile.json") }

    static func loadProfile() -> CarProfile? {
        guard let data = try? Data(contentsOf: profileURL) else { return nil }
        return try? JSONDecoder().decode(CarProfile.self, from: data)
    }

    static func saveProfile(_ profile: CarProfile) throws {
        let data = try JSONEncoder().encode(profile)
        try write(data, to: profileURL)
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

    struct NextUp: Codable { var title: String; var detail: String; var updated: Date }

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
