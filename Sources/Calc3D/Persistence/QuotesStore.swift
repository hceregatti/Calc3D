import Foundation

/// Persists quote snapshots in versioned JSON stored locally in UserDefaults.
struct QuotesStore {
    private let defaults: UserDefaults

    static let storageKey = "calc3d.quotes.v1"
    private static let currentVersion = 1

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [QuoteRecord] {
        guard
            let data = defaults.data(forKey: Self.storageKey),
            let payload = try? JSONDecoder().decode(Payload.self, from: data),
            payload.version == Self.currentVersion
        else {
            return []
        }
        return payload.records.sorted { $0.savedAt > $1.savedAt }
    }

    func save(_ records: [QuoteRecord]) {
        let payload = Payload(version: Self.currentVersion, records: records)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    private struct Payload: Codable {
        var version: Int
        var records: [QuoteRecord]
    }
}
