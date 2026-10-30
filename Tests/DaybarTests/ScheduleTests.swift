import XCTest
@testable import Daybar

final class ScheduleTests: XCTestCase {
    var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }
    func date(_ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 30, hour: hour, minute: minute))!
    }
    func testBeforeFirstActivityHasNoCurrentBlock() {
        XCTAssertNil(Schedule.current(Block.defaults, at: date(6), calendar: calendar))
    }
    func testTransitionOccursAtExactMinute() {
        XCTAssertEqual(Schedule.current(Block.defaults, at: date(6, 59), calendar: calendar)?.title, "Breakfast + Plan Day")
        XCTAssertEqual(Schedule.current(Block.defaults, at: date(7), calendar: calendar)?.title, "Morning routine")
    }
    func testExcludedWeekdaysDoNotBecomeCurrent() {
        let block = Block(title: "Sunday", minute: 0, symbol: "star", weekdays: [1])
        XCTAssertNil(Schedule.current([block], at: date(12), calendar: calendar))
    }
    func testTimeFormatting() {
        XCTAssertEqual(Schedule.time(0), "12:00 AM")
        XCTAssertEqual(Schedule.time(720), "12:00 PM")
        XCTAssertEqual(Schedule.time(1020), "5:00 PM")
    }
    func testWakeShowsOnlyLatestTransition() {
        XCTAssertEqual(Schedule.transition(Block.defaults, after: date(6), through: date(12, 30), calendar: calendar)?.minute, 720)
    }
    func testTransitionDoesNotRepeatOnNextTick() {
        XCTAssertEqual(Schedule.transition(Block.defaults, after: date(6, 59), through: date(7), calendar: calendar)?.title, "Morning routine")
        XCTAssertNil(Schedule.transition(Block.defaults, after: date(7), through: date(7, 1), calendar: calendar))
    }
    func testBackwardsClockDoesNotTriggerReminder() {
        XCTAssertNil(Schedule.transition(Block.defaults, after: date(12), through: date(7), calendar: calendar))
    }
}
