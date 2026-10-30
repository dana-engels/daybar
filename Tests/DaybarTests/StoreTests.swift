import XCTest
@testable import Daybar

@MainActor
private final class TestLogin: LoginManaging {
    var enabled = false
    var approvalRequired = false
    var fail = false
    func setEnabled(_ enabled: Bool) throws {
        if fail { throw CocoaError(.featureUnsupported) }
        self.enabled = enabled
    }
}

@MainActor
private final class TestClock {
    var date: Date
    init(_ iso: String = "2026-10-30T06:59:00Z") { date = ISO8601DateFormatter().date(from: iso)! }
}

@MainActor
final class StoreTests: XCTestCase {
    private func fixture(_ body: (Store, TestClock, TestLogin, UserDefaults) throws -> Void) throws {
        let suite = "DaybarTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let clock = TestClock()
        let login = TestLogin()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let fixedCalendar = calendar
        let store = Store(preferences: PreferencesRepository(defaults: defaults), login: login, clock: { clock.date }, calendar: { fixedCalendar })
        try body(store, clock, login, defaults)
    }

    func testQuietModeChangesActivityWithoutReplayingReminder() async throws {
        try fixture { store, clock, _, _ in
            var reminders: [Block] = []
            store.showReminder = { reminders.append($0) }
            store.quiet = true
            clock.date.addTimeInterval(60)
            store.tick()
            XCTAssertEqual(store.timeline.current?.minute, 420)
            store.quiet = false
            clock.date.addTimeInterval(1)
            store.tick()
            XCTAssertTrue(reminders.isEmpty)
        }
    }

    func testEditingAndPersistenceKeepExistingIDs() async throws {
        try fixture { store, clock, _, defaults in
            var reminders: [Block] = []
            store.showReminder = { reminders.append($0) }
            clock.date.addTimeInterval(120)
            let id = store.blocks[0].id
            store.blocks[0].minute = 421
            store.blocks[0].title = "Updated"
            store.tick()
            XCTAssertTrue(reminders.isEmpty)
            XCTAssertEqual(store.timeline.current?.id, id)
            let loaded = try PreferencesRepository(defaults: defaults).loadBlocks()
            XCTAssertEqual(loaded, store.blocks)
        }
    }

    func testCustomColorAndAnimationSettingsSurviveReload() async throws {
        try fixture { store, _, _, defaults in
            store.appearance.preset = nil
            store.appearance.custom = RGBColor(0.1, 0.2, 0.3)
            store.animated = false
            let repository = PreferencesRepository(defaults: defaults)
            let loaded = try repository.loadAppearance()
            XCTAssertNil(loaded.preset)
            XCTAssertEqual(loaded.custom, RGBColor(0.1, 0.2, 0.3))
            XCTAssertFalse(repository.animationsEnabled)
        }
    }

    func testLoginFailureIsVisibleWithoutPretendingItSucceeded() async throws {
        try fixture { store, _, login, _ in
            login.fail = true
            store.setLogin(true)
            XCTAssertFalse(store.loginEnabled)
            XCTAssertNotNil(store.loginMessage)
            login.fail = false
            store.setLogin(true)
            XCTAssertTrue(store.loginEnabled)
            XCTAssertNil(store.loginMessage)
        }
    }

    func testCorruptPreferencesArePreservedUntilUserEdits() async throws {
        let suite = "DaybarTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let corrupt = Data("broken".utf8)
        defaults.set(corrupt, forKey: "blocks")
        let store = Store(preferences: PreferencesRepository(defaults: defaults), login: TestLogin())
        XCTAssertNotNil(store.storageMessage)
        XCTAssertEqual(store.blocks, Block.defaults)
        XCTAssertEqual(defaults.data(forKey: "blocks"), corrupt)
        store.blocks[0].title = "Recovered"
        XCTAssertNil(store.storageMessage)
        XCTAssertEqual(try PreferencesRepository(defaults: defaults).loadBlocks()[0].title, "Recovered")
    }

    func testWakeUpdatesCurrentAndShowsOnlyLatestReminder() async throws {
        try fixture { store, clock, _, _ in
            var reminders: [Block] = []
            store.showReminder = { reminders.append($0) }
            clock.date = ISO8601DateFormatter().date(from: "2026-10-30T12:30:00Z")!
            store.synchronize()
            XCTAssertEqual(reminders.map(\.minute), [720])
            XCTAssertEqual(store.timeline.current?.minute, 720)
            store.synchronize()
            XCTAssertEqual(reminders.count, 1)
        }
    }
    func testClockChangeAcrossSpringForwardDoesNotMissReminder() async throws {
        let suite = "DaybarTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let clock = TestClock("2026-03-08T09:59:00Z")
        var local = Calendar(identifier: .gregorian)
        local.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let fixedCalendar = local
        let store = Store(preferences: PreferencesRepository(defaults: defaults), login: TestLogin(), clock: { clock.date }, calendar: { fixedCalendar })
        store.blocks = [Block(title: "Skipped hour", minute: 150, symbol: "star")]
        var reminders: [Block] = []
        store.showReminder = { reminders.append($0) }
        clock.date = ISO8601DateFormatter().date(from: "2026-03-08T10:00:00Z")!
        store.synchronize()
        store.synchronize()
        XCTAssertEqual(reminders.count, 1)
        XCTAssertEqual(store.timeline.current?.minute, 150)
    }

}
