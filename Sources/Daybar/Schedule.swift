import Foundation

struct Block: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var minute: Int
    var symbol: String
    var weekdays: [Int] = Array(1...7)

    init(id: UUID = UUID(), title: String, minute: Int, symbol: String, weekdays: [Int] = Array(1...7)) {
        self.id = id
        self.title = title
        self.minute = minute
        self.symbol = symbol
        self.weekdays = weekdays
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        title = try values.decode(String.self, forKey: .title)
        minute = try values.decode(Int.self, forKey: .minute)
        symbol = try values.decode(String.self, forKey: .symbol)
        weekdays = try values.decode([Int].self, forKey: .weekdays)
        guard (0..<1440).contains(minute), weekdays.allSatisfy({ (1...7).contains($0) }) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid activity time or weekday."))
        }
        weekdays = Array(Set(weekdays)).sorted()
    }

    var displayTitle: String {
        Self.usableTitle(title) ?? "Untitled activity"
    }

    static func usableTitle(_ text: String) -> String? {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : text
    }

    static let defaults: [Block] = [
        Block(title: "Breakfast + Plan Day", minute: 375, symbol: "sun.max.fill"),
        Block(title: "Morning routine", minute: 420, symbol: "heart.fill"),
        Block(title: "Focus", minute: 480, symbol: "book.fill"),
        Block(title: "Walk", minute: 600, symbol: "figure.walk"),
        Block(title: "BREAK", minute: 660, symbol: "cup.and.saucer.fill"),
        Block(title: "Focus", minute: 720, symbol: "book.fill"),
        Block(title: "Projects", minute: 900, symbol: "hammer.fill"),
        Block(title: "Wrap Up", minute: 1020, symbol: "moon.fill")
    ]
}

enum Schedule {
    struct Timeline: Equatable {
        var current: Block?
        var next: Block?
    }

    struct Occurrence {
        let block: Block
        let date: Date
        var identity: Identity { Identity(blockID: block.id, date: date) }
        struct Identity: Hashable {
            let blockID: UUID
            let date: Date
        }
    }

    static func ordered(_ blocks: [Block]) -> [Block] {
        blocks.sorted { $0.minute == $1.minute ? $0.id.uuidString < $1.id.uuidString : $0.minute < $1.minute }
    }

    static func today(_ blocks: [Block], at date: Date, calendar: Calendar = .current) -> [Block] {
        ordered(blocks.filter { $0.weekdays.contains(calendar.component(.weekday, from: date)) })
    }

    static func occurrences(_ blocks: [Block], at date: Date, calendar: Calendar = .current) -> [Occurrence] {
        var events: [Occurrence] = []
        for block in today(blocks, at: date, calendar: calendar) {
            guard (0..<1440).contains(block.minute),
                  let due = dueDate(minute: block.minute, on: date, calendar: calendar) else { continue }
            // Ordered by scheduled minute, then ID. The last activity at an instant wins.
            if events.last?.date == due { events.removeLast() }
            events.append(Occurrence(block: block, date: due))
        }
        return events
    }

    private static func dueDate(minute: Int, on day: Date, calendar: Calendar) -> Date? {
        let start = calendar.startOfDay(for: day)
        if let due = calendar.date(bySettingHour: minute / 60, minute: minute % 60, second: 0,
                                   of: start, matchingPolicy: .nextTime, repeatedTimePolicy: .first),
           calendar.isDate(due, inSameDayAs: day) {
            return due
        }
        // Foundation can advance to tomorrow for a gap shorter than one hour.
        // The transition instant itself is the first valid time after the gap.
        guard let jump = calendar.timeZone.nextDaylightSavingTimeTransition(after: start.addingTimeInterval(-1)),
              calendar.isDate(jump, inSameDayAs: day) else { return nil }
        let zone = calendar.timeZone
        let gap = zone.secondsFromGMT(for: jump) - zone.secondsFromGMT(for: jump.addingTimeInterval(-1))
        let end = calendar.component(.hour, from: jump) * 3600 + calendar.component(.minute, from: jump) * 60
        return gap > 0 && minute * 60 >= end - gap && minute * 60 < end ? jump : nil
    }

    static func timeline(_ blocks: [Block], at date: Date, calendar: Calendar = .current) -> Timeline {
        let events = occurrences(blocks, at: date, calendar: calendar)
        return Timeline(current: events.last { $0.date <= date }?.block, next: events.first { $0.date > date }?.block)
    }

    static func current(_ blocks: [Block], at date: Date, calendar: Calendar = .current) -> Block? {
        timeline(blocks, at: date, calendar: calendar).current
    }

    static func transition(_ blocks: [Block], after previous: Date, through date: Date, calendar: Calendar = .current) -> Block? {
        latestTransition(blocks, after: previous, through: date, calendar: calendar)?.block
    }

    static func latestTransition(_ blocks: [Block], after previous: Date, through date: Date, calendar: Calendar = .current) -> Occurrence? {
        guard date > previous else { return nil }
        return occurrences(blocks, at: date, calendar: calendar).last { $0.date > previous && $0.date <= date }
    }

    static func time(_ minute: Int) -> String {
        String(format: "%d:%02d %@", (minute / 60 + 11) % 12 + 1, minute % 60, minute < 720 ? "AM" : "PM")
    }
}

/// Tracks transitions independently of UI, timers, and notification presentation.
struct ReminderScheduler {
    private var previous: Date
    private var emitted: Set<Schedule.Occurrence.Identity> = []

    init(at date: Date) { previous = date }

    mutating func rebase(at date: Date) { previous = date }

    mutating func poll(_ blocks: [Block], at date: Date, calendar: Calendar = .current) -> Block? {
        defer { previous = date }
        // Keep a small replay guard across clock changes, midnight, and wake events.
        emitted = emitted.filter { date.timeIntervalSince($0.date) < 172_800 }
        guard let event = Schedule.latestTransition(blocks, after: previous, through: date, calendar: calendar),
              emitted.insert(event.identity).inserted else { return nil }
        return event.block
    }
}
