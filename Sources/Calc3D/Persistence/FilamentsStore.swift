import Calc3DCore
import Foundation

/// Persiste a biblioteca de filamentos em JSON versionado no UserDefaults.
struct FilamentsStore {
    private let defaults: UserDefaults

    static let storageKey = "calc3d.filaments.v1"
    private static let currentVersion = 1

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [Filament] {
        guard
            let data = defaults.data(forKey: Self.storageKey),
            let payload = try? JSONDecoder().decode(Payload.self, from: data),
            payload.version == Self.currentVersion
        else {
            return []
        }
        return payload.records
    }

    func save(_ proposals: [Filament]) {
        let payload = Payload(version: Self.currentVersion, records: proposals)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    private struct Payload: Codable {
        var version: Int
        var records: [Filament]
    }
}
