import Foundation

/// Preferência do catálogo neste Mac: a pasta compartilhada com os modelos 3D.
struct CatalogSettingsStore {
    private let defaults: UserDefaults

    private static let folderKey = "calc3d.catalog.folder"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var folderPath: String? {
        get { defaults.string(forKey: Self.folderKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.folderKey) }
    }
}
