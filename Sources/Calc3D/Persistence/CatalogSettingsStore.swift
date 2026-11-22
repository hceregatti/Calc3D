import Foundation

/// Preferências do catálogo neste Mac: pasta compartilhada, nome do usuário e seu identificador.
struct CatalogSettingsStore {
    private let defaults: UserDefaults

    private static let folderKey = "calc3d.catalog.folder"
    private static let nameKey = "calc3d.catalog.userName"
    private static let userIDKey = "calc3d.catalog.userID"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var folderPath: String? {
        get { defaults.string(forKey: Self.folderKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.folderKey) }
    }

    var userName: String {
        get { defaults.string(forKey: Self.nameKey) ?? "" }
        nonmutating set { defaults.set(newValue, forKey: Self.nameKey) }
    }

    /// Identifica o autor nas entradas; gerado na primeira vez e mantido depois.
    var userID: UUID {
        if let text = defaults.string(forKey: Self.userIDKey), let id = UUID(uuidString: text) { return id }
        let id = UUID()
        defaults.set(id.uuidString, forKey: Self.userIDKey)
        return id
    }
}
