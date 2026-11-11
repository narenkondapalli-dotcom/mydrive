import Foundation

/// Deterministic mode for XCUITest. Launch arguments:
///   -uitest                 use /tmp/mydrive-uitest as the data folder (shared with the test runner on the simulator)
///   -uitest-reset           wipe that folder first
///   -uitest-seed            create a profile (Jeep Meridian, owner Mohit) if none exists
///   -uitest-colour <name>   paint of the seeded profile (default Pearl White)
///   -uitest-hour <0-23>     pin "now" to today at that hour
/// Has no effect in a normal launch.
enum UITestSupport {
    static let folder = URL(fileURLWithPath: "/tmp/mydrive-uitest")
    private(set) static var isActive = false

    static func configure(arguments: [String] = ProcessInfo.processInfo.arguments) {
        guard arguments.contains("-uitest") else { return }
        isActive = true
        if arguments.contains("-uitest-reset") { try? FileManager.default.removeItem(at: folder) }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        SharedStore.containerOverride = folder
        if let h = value("-uitest-hour", in: arguments).flatMap(Int.init) { setHour(h) }
        if arguments.contains("-uitest-seed"), SharedStore.loadProfile() == nil {
            let colour = value("-uitest-colour", in: arguments) ?? "Pearl White"
            let p = CarProfile(make: "Jeep", model: "Meridian", colour: colour, roof: "Body", wheels: "", nickname: "",
                               renderId: nil, ownerName: "Mohit")
            try? SharedStore.saveProfile(p)
        }
    }

    static func setHour(_ hour: Int) {
        AppClock.override = Calendar.current.date(bySettingHour: min(max(hour, 0), 23), minute: 15, second: 0, of: Date())
    }

    private static func value(_ key: String, in args: [String]) -> String? {
        guard let i = args.firstIndex(of: key), args.indices.contains(i + 1) else { return nil }
        return args[i + 1]
    }
}
