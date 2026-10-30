import Foundation

struct Block: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var minute: Int
    var symbol: String
    var weekdays: [Int] = Array(1...7)
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
    static func transition(_ blocks: [Block], after previous: Date, through date: Date, calendar: Calendar = .current) -> Block? {
        guard date > previous else { return nil }
        return today(blocks, at: date, calendar: calendar).last { block in
            guard let due = calendar.date(bySettingHour: block.minute / 60, minute: block.minute % 60, second: 0, of: date) else { return false }
            return due > previous && due <= date
        }
    }
    static func today(_ blocks: [Block], at date: Date, calendar: Calendar = .current) -> [Block] {
        blocks.filter { $0.weekdays.contains(calendar.component(.weekday, from: date)) }
            .sorted { $0.minute == $1.minute ? $0.id.uuidString < $1.id.uuidString : $0.minute < $1.minute }
    }
    static func current(_ blocks: [Block], at date: Date, calendar: Calendar = .current) -> Block? {
        let minute = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        return today(blocks, at: date, calendar: calendar).last { $0.minute <= minute }
    }
    static func time(_ minute: Int) -> String {
        String(format: "%d:%02d %@", (minute / 60 + 11) % 12 + 1, minute % 60, minute < 720 ? "AM" : "PM")
    }
}
