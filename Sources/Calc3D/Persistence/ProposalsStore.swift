import Foundation

/// Persiste propostas em JSON versionado no UserDefaults.
struct ProposalsStore {
    private let defaults: UserDefaults

    static let storageKey = "calc3d.proposals.v1"
    private static let currentVersion = 1

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [ProposalRecord] {
        guard
            let data = defaults.data(forKey: Self.storageKey),
            let payload = try? JSONDecoder().decode(Payload.self, from: data),
            payload.version == Self.currentVersion
        else {
            return []
        }
        return payload.records.sorted { $0.updatedAt > $1.updatedAt }
    }

    func save(_ proposals: [ProposalRecord]) {
        let payload = Payload(version: Self.currentVersion, records: proposals)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    private struct Payload: Codable {
        var version: Int
        var records: [ProposalRecord]
    }
}
