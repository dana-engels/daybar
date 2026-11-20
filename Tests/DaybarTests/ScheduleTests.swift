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
    func testClockRollbackDoesNotRepeatAnEmittedReminder() {
        var scheduler = ReminderScheduler(at: date(6, 59))
        XCTAssertNotNil(scheduler.poll(Block.defaults, at: date(7), calendar: calendar))
        XCTAssertNil(scheduler.poll(Block.defaults, at: date(6, 59), calendar: calendar))
        XCTAssertNil(scheduler.poll(Block.defaults, at: date(7), calendar: calendar))
    }
    func testSpringForwardUsesSameOccurrenceForTimelineAndReminder() {
        var local = calendar
        local.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let before = ISO8601DateFormatter().date(from: "2026-03-08T09:59:00Z")!
        let after = ISO8601DateFormatter().date(from: "2026-03-08T10:00:00Z")!
        let block = Block(title: "Skipped hour", minute: 150, symbol: "star")
        XCTAssertNil(Schedule.current([block], at: before, calendar: local))
        XCTAssertEqual(Schedule.transition([block], after: before, through: after, calendar: local)?.id, block.id)
        XCTAssertEqual(Schedule.current([block], at: after, calendar: local)?.id, block.id)
    }
    func testSpringCollisionPreviewsAndAnnouncesOnlyTheWinner() {
        var local = calendar
        local.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let before = ISO8601DateFormatter().date(from: "2026-03-08T09:59:00Z")!
        let after = before.addingTimeInterval(60)
        let activities = [135, 165, 180].map { Block(title: "Routine", minute: $0, symbol: "book") }
        for group in [Array(activities.prefix(2)), activities] {
            let winner = group.last?.id
            var scheduler = ReminderScheduler(at: before)
            XCTAssertEqual(Schedule.timeline(group.reversed(), at: before, calendar: local).next?.id, winner)
            XCTAssertEqual(Schedule.current(group, at: after, calendar: local)?.id, winner)
            XCTAssertEqual(scheduler.poll(group, at: after, calendar: local)?.id, winner)
            XCTAssertNil(scheduler.poll(group, at: after.addingTimeInterval(60), calendar: local))
        }
    }

    func testHalfHourSpringGapMovesActivitiesToFirstValidMinute() {
        var local = calendar
        local.timeZone = TimeZone(identifier: "Australia/Lord_Howe")!
        let jump = ISO8601DateFormatter().date(from: "2026-10-03T15:30:00Z")!
        let before = jump.addingTimeInterval(-60)
        let activities = [120, 135, 150].map { Block(title: "Routine", minute: $0, symbol: "book") }
        for group in [Array(activities.prefix(2)), activities] {
            XCTAssertEqual(Schedule.timeline(group, at: before, calendar: local).next, group.last)
            XCTAssertEqual(Schedule.current(group, at: jump, calendar: local), group.last)
            XCTAssertEqual(Schedule.transition(group, after: before, through: jump, calendar: local), group.last)
        }
    }

    func testBlankEditsPreserveLastUsableTitleAndLegacyBlanksHaveFallback() {
        let block = Block(title: "  ", minute: 120, symbol: "book")
        XCTAssertEqual(block.displayTitle, "Untitled activity")
        let original = "Read"
        for draft in ["Rea", "Re", "R", "", "  "] {
            let saved = Block.usableTitle(draft) ?? original
            XCTAssertEqual(saved, draft.trimmingCharacters(in: .whitespaces).isEmpty ? original : draft)
        }
    }

    func testFallBackDoesNotMakeCurrentActivityMoveBackwards() {
        var local = calendar
        local.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let repeatedHour = ISO8601DateFormatter().date(from: "2026-11-01T09:10:00Z")!
        let first = Block(title: "Earlier", minute: 0, symbol: "star")
        let second = Block(title: "Current", minute: 90, symbol: "star")
        let third = Block(title: "Next", minute: 120, symbol: "star")
        let timeline = Schedule.timeline([first, second, third], at: repeatedHour, calendar: local)
        XCTAssertEqual(timeline.current?.id, second.id)
        XCTAssertEqual(timeline.next?.id, third.id)
    }
    func testMidnightDoesNotCarryPreviousDaysActivity() {
        let nextDay = calendar.date(byAdding: .day, value: 1, to: date(0))!
        XCTAssertNil(Schedule.current(Block.defaults, at: nextDay, calendar: calendar))
        XCTAssertNil(Schedule.transition(Block.defaults, after: date(16), through: nextDay, calendar: calendar))
    }

}
