import XCTest
@testable import MyDrive

/// Points the shared store at a fresh temp folder for every test.
class IsolatedStoreTestCase: XCTestCase {
    var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    override func setUp() {
        super.setUp()
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("mydrive-test-\(UUID())")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        SharedStore.containerOverride = dir
    }

    override func tearDown() {
        if let dir = SharedStore.containerOverride { try? FileManager.default.removeItem(at: dir) }
        SharedStore.containerOverride = nil
        super.tearDown()
    }

    func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 9, _ min: Int = 0) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    func profile(name: String = "Mohit", colour: String = "Pearl White", model: String = "Meridian") -> CarProfile {
        CarProfile(make: "Jeep", model: model, colour: colour, roof: "Body", wheels: "", nickname: "", renderId: nil, ownerName: name)
    }

    func drive(_ start: Date, minutes: Double = 30, km: Double = 10, from: String = "Home", to: String = "Clinic") -> Drive {
        Drive(startTs: start, endTs: start.addingTimeInterval(minutes * 60), distanceKm: km, startLabel: from, endLabel: to)
    }
}
