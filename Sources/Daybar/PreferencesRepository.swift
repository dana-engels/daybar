import Foundation

/// Keeps the existing keys and formats so upgrades preserve users' routines and colors.
struct PreferencesRepository {
    let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func loadBlocks() throws -> [Block] {
        let blocks: [Block] = try load("blocks", fallback: Block.defaults)
        guard Set(blocks.map(\.id)).count == blocks.count else {
            throw CocoaError(.coderReadCorrupt)
        }
        return blocks
    }
    func loadAppearance() throws -> Appearance { try load("appearance", fallback: Appearance()) }
    var animationsEnabled: Bool { defaults.object(forKey: "animated") as? Bool ?? true }

    func saveBlocks(_ blocks: [Block]) throws { try save(blocks, key: "blocks") }
    func saveAppearance(_ appearance: Appearance) throws { try save(appearance, key: "appearance") }
    func saveAnimations(_ enabled: Bool) { defaults.set(enabled, forKey: "animated") }

    private func load<Value: Decodable>(_ key: String, fallback: Value) throws -> Value {
        guard let object = defaults.object(forKey: key) else { return fallback }
        guard let data = object as? Data else { throw CocoaError(.coderReadCorrupt) }
        return try JSONDecoder().decode(Value.self, from: data)
    }
    private func save<Value: Encodable>(_ value: Value, key: String) throws {
        defaults.set(try JSONEncoder().encode(value), forKey: key)
    }
}
