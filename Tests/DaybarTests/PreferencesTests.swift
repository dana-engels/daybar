import XCTest
@testable import Daybar

final class PreferencesTests: XCTestCase {
    func testInvalidTimeAndWeekdayAreRejected() throws {
        for block in [Block(title: "Invalid", minute: 1440, symbol: "star"), Block(title: "Invalid", minute: 0, symbol: "star", weekdays: [0])] {
            XCTAssertThrowsError(try JSONDecoder().decode(Block.self, from: JSONEncoder().encode(block)))
        }
    }
    func testDuplicateActivityIDsAreRejected() throws {
        let suite = "DaybarTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let block = Block(title: "Duplicate", minute: 0, symbol: "star")
        defaults.set(try JSONEncoder().encode([block, block]), forKey: "blocks")
        XCTAssertThrowsError(try PreferencesRepository(defaults: defaults).loadBlocks())
    }
    func testOutOfRangeColorIsRejected() throws {
        let data = Data("{\"red\":2,\"green\":0,\"blue\":0}".utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(RGBColor.self, from: data))
    }
    func testExistingActivityFormatLoadsUnchanged() throws {
        let block = Block(title: "Existing activity", minute: 720, symbol: "star.fill", weekdays: [2,3,4,5,6])
        let loaded = try JSONDecoder().decode(Block.self, from: JSONEncoder().encode(block))
        XCTAssertEqual(loaded, block)
    }
}
