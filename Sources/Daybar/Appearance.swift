import SwiftUI
import AppKit

struct RGBColor: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var color: Color { Color(red: red, green: green, blue: blue) }
    init(_ red: Double, _ green: Double, _ blue: Double) {
        self.red = red; self.green = green; self.blue = blue
    }
    init?(color: Color) {
        guard let rgb = NSColor(color).usingColorSpace(.sRGB) else { return nil }
        self.init(rgb.redComponent, rgb.greenComponent, rgb.blueComponent)
    }
}

enum AccentPreset: String, Codable, CaseIterable, Identifiable {
    case iris, ocean, lagoon, sage, amber, rose
    var id: String { rawValue }
    var name: String { rawValue.capitalized }
    var color: Color {
        switch self {
        case .iris: return .indigo
        case .ocean: return .blue
        case .lagoon: return .teal
        case .sage: return Color(red: 0.38, green: 0.59, blue: 0.43)
        case .amber: return Color(red: 0.78, green: 0.48, blue: 0.12)
        case .rose: return .pink
        }
    }
}

struct Appearance: Codable {
    var preset: AccentPreset? = .iris
    var custom = RGBColor(0.45, 0.39, 0.85)
    var accent: Color { preset?.color ?? custom.color }
}
