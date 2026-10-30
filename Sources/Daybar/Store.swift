import SwiftUI

@MainActor
final class Store: ObservableObject {
    @Published var blocks: [Block] {
        didSet {
            persist(key: "blocks") { try preferences.saveBlocks(blocks) }
            // Editing the routine must not generate a reminder retroactively.
            scheduler.rebase(at: clock())
            refreshTimeline()
        }
    }
    @Published var appearance: Appearance {
        didSet { persist(key: "appearance") { try preferences.saveAppearance(appearance) } }
    }
    @Published var quiet = false
    @Published var animated: Bool { didSet { preferences.saveAnimations(animated) } }
    @Published private(set) var now: Date
    @Published private(set) var timeline: Schedule.Timeline
    @Published private(set) var loginEnabled = false
    @Published private(set) var loginMessage: String?
    @Published private(set) var storageMessage: String?

    var showReminder: ((Block) -> Void)?
    private let preferences: PreferencesRepository
    private let login: any LoginManaging
    private let clock: () -> Date
    private let calendar: () -> Calendar
    private var scheduler: ReminderScheduler
    private var timer: Timer?
    private var running = false
    private var storageIssues: [String: String] = [:]

    init(preferences: PreferencesRepository = PreferencesRepository(),
         login: any LoginManaging = LoginManager(),
         clock: @escaping () -> Date = Date.init,
         calendar: @escaping () -> Calendar = { .current }) {
        self.preferences = preferences
        self.login = login
        self.clock = clock
        self.calendar = calendar
        let date = clock()
        now = date
        scheduler = ReminderScheduler(at: date)
        var messages: [String: String] = [:]
        let loadedBlocks: [Block]
        do { loadedBlocks = try preferences.loadBlocks() }
        catch {
            loadedBlocks = Block.defaults
            messages["blocks"] = "Your saved routine could not be read. A starter routine is shown; the saved data is kept until you edit it."
        }
        blocks = loadedBlocks
        do { appearance = try preferences.loadAppearance() }
        catch {
            appearance = Appearance()
            messages["appearance"] = "Your saved color could not be read. Iris is shown until you choose a color."
        }
        animated = preferences.animationsEnabled
        timeline = Schedule.timeline(loadedBlocks, at: date, calendar: calendar())
        storageIssues = messages
        storageMessage = messages.isEmpty ? nil : messages.keys.sorted().compactMap { messages[$0] }.joined(separator: "\n")
        refreshLogin()
    }

    func start() {
        guard !running else { return }
        running = true
        refreshTimeline()
        armTimer()
    }

    func stop() {
        running = false
        timer?.invalidate()
        timer = nil
    }

    func tick() {
        let date = clock()
        let reminder = scheduler.poll(blocks, at: date, calendar: calendar())
        refreshTimeline(at: date)
        // Quiet mode still consumes transitions, so unmuting never replays them.
        if let reminder, !quiet { showReminder?(reminder) }
    }

    func synchronize() {
        tick()
        if running { armTimer() }
    }

    func setLogin(_ enabled: Bool) {
        do {
            try login.setEnabled(enabled)
            refreshLogin()
        } catch {
            refreshLogin()
            loginMessage = error.localizedDescription
        }
    }

    func refreshLogin() {
        loginEnabled = login.enabled
        loginMessage = login.approvalRequired ? "Approve Daybar in System Settings → General → Login Items." : nil
    }

    private func refreshTimeline(at date: Date? = nil) {
        let date = date ?? clock()
        now = date
        let updated = Schedule.timeline(blocks, at: date, calendar: calendar())
        if updated != timeline { timeline = updated }
    }

    private func armTimer() {
        timer?.invalidate()
        let date = clock()
        let next = calendar().nextDate(after: date, matching: DateComponents(second: 0), matchingPolicy: .nextTime) ?? date.addingTimeInterval(60)
        let timer = Timer(fire: next, interval: 0, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.running else { return }
                self.tick()
                self.armTimer()
            }
        }
        timer.tolerance = 0.2
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func persist(key: String, _ action: () throws -> Void) {
        do {
            try action()
            storageIssues.removeValue(forKey: key)
        } catch {
            storageIssues[key] = "A setting could not be saved: \(error.localizedDescription)"
        }
        storageMessage = storageIssues.isEmpty ? nil : storageIssues.keys.sorted().compactMap { storageIssues[$0] }.joined(separator: "\n")
    }
}
