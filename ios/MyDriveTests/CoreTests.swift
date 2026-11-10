import XCTest
@testable import MyDrive

final class CoreTests: XCTestCase {
    func testProfileRoundTrip() throws {
        let p = CarProfile(make: "Jeep", model: "Meridian", colour: "White", roof: "Black", wheels: "Black",
                           nickname: "", renderId: nil, ownerName: "Mohit")
        try SharedStore.saveProfile(p)
        XCTAssertEqual(SharedStore.loadProfile(), p)
        XCTAssertEqual(p.displayName, "Meridian")
    }

    func testMetricsWritesJSONLines() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("m-\(UUID()).jsonl")
        let m = Metrics(fileURL: url)
        m.markConnect(); m.log(.welcomeStarted)
        let exp = expectation(description: "flush"); DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { exp.fulfill() }
        wait(for: [exp], timeout: 2)
        let lines = try String(contentsOf: url, encoding: .utf8).split(separator: "\n")
        XCTAssertEqual(lines.count, 2)
        XCTAssertTrue(lines[1].contains("\"ms_since_connect\""))
    }

    func testBriefingMentionsCar() throws {
        try SharedStore.saveProfile(CarProfile(make: "Jeep", model: "Meridian", colour: "White", roof: "Black",
                                               wheels: "Black", nickname: "", renderId: nil, ownerName: "Mohit"))
        XCTAssertTrue(BriefingBuilder.build().contains("Meridian"))
    }
}
