import AppKit

/// Fatiadores em que um modelo do catálogo pode ser aberto.
enum Slicer: String, CaseIterable, Identifiable {
    case bambuStudio
    case crealityPrint

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bambuStudio: "Bambu Studio"
        case .crealityPrint: "Creality Print"
        }
    }

    private var bundleIdentifiers: [String] {
        switch self {
        case .bambuStudio: ["com.bambulab.bambu-studio"]
        case .crealityPrint: ["com.creality.print", "com.creality.CrealityPrint", "com.creality.creality-print"]
        }
    }

    /// Trecho do nome do app, usado quando o identificador não bate (ex.: "Creality Print 6.app").
    private var nameKeyword: String {
        switch self {
        case .bambuStudio: "bambustudio"
        case .crealityPrint: "crealityprint"
        }
    }

    /// Onde o app está instalado, ou nil.
    var applicationURL: URL? {
        for identifier in bundleIdentifiers {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier) { return url }
        }
        let fm = FileManager.default
        let folders = [URL(filePath: "/Applications"), fm.homeDirectoryForCurrentUser.appending(path: "Applications")]
        for folder in folders {
            guard let apps = try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else { continue }
            let normalized: (URL) -> String = { $0.deletingPathExtension().lastPathComponent.lowercased().filter { !$0.isWhitespace } }
            if let match = apps.first(where: { $0.pathExtension == "app" && normalized($0).contains(nameKeyword) }) { return match }
        }
        return nil
    }
}
