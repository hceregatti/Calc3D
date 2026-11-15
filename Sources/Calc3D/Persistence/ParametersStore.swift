import Calc3DCore
import Foundation

/// Salva e carrega os parâmetros do usuário no UserDefaults, em JSON.
struct ParametersStore {
    private let defaults: UserDefaults

    static let settingsKey = "calc3d.settings.v1"
    static let jobKey = "calc3d.job.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadSettings() -> ShopSettings { load(Self.settingsKey) ?? .defaults }
    func loadJob() -> PrintJob { load(Self.jobKey) ?? .defaults }

    func save(_ settings: ShopSettings) { save(settings, key: Self.settingsKey) }
    func save(_ job: PrintJob) { save(job, key: Self.jobKey) }

    private func load<T: Decodable>(_ key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func save<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }
}
