import Calc3DCore
import Foundation

/// Salva e carrega os parâmetros do usuário no UserDefaults.
struct ParametersStore {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "calc3d.parameters.v1") {
        self.defaults = defaults
        self.key = key
    }

    func load() -> PrintParameters {
        guard let data = defaults.data(forKey: key),
              let params = try? JSONDecoder().decode(PrintParameters.self, from: data)
        else { return .defaults }
        return params
    }

    func save(_ params: PrintParameters) {
        guard let data = try? JSONEncoder().encode(params) else { return }
        defaults.set(data, forKey: key)
    }
}
