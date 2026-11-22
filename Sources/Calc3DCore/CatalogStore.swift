import Foundation

/// Modelo 3D (3MF/STL) já configurado, guardado na pasta compartilhada do catálogo.
public struct CatalogFile: Identifiable, Equatable, Sendable {
    public static let supportedExtensions: Set<String> = ["3mf", "stl"]

    public var url: URL
    public var modifiedAt: Date
    /// Pasta onde o arquivo está, relativa à pasta do catálogo ("" se estiver na raiz).
    public var folder: String

    public var id: String { url.path }
    public var name: String { url.deletingPathExtension().lastPathComponent }
    public var fileExtension: String { url.pathExtension.lowercased() }

    public init(url: URL, modifiedAt: Date, folder: String = "") {
        self.url = url
        self.modifiedAt = modifiedAt
        self.folder = folder
    }
}

public enum CatalogError: Error, Equatable, Sendable {
    case folderUnavailable
}

/// Conteúdo lido do catálogo.
public struct CatalogListing: Sendable {
    public var files: [CatalogFile] = []
    /// Arquivos da nuvem ainda não baixados (entram na próxima atualização).
    public var pendingDownloads = 0

    public init() {}
}

/// Catálogo em pasta compartilhada (iCloud Drive, Drive, Dropbox, rede…): lista os 3MF/STL que houver nela.
public struct FolderCatalogStore: Sendable {
    public let root: URL

    public init(root: URL) { self.root = root }

    public func list() throws -> CatalogListing {
        let fm = FileManager.default
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: root.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw CatalogError.folderUnavailable
        }
        var listing = CatalogListing()
        // Sem pular ocultos: os placeholders do iCloud (".<arquivo>.3mf.icloud") começam com ponto.
        guard let walker = fm.enumerator(
            at: root, includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
            options: [.skipsPackageDescendants]
        ) else { return listing }

        let rootPath = root.standardizedFileURL.path
        for case let url as URL in walker {
            let name = url.lastPathComponent
            if name.hasPrefix("."), name.hasSuffix(".icloud") {
                let real = String(name.dropFirst().dropLast(".icloud".count))
                guard CatalogFile.supportedExtensions.contains((real as NSString).pathExtension.lowercased()) else { continue }
                try? fm.startDownloadingUbiquitousItem(at: url.deletingLastPathComponent().appendingPathComponent(real))
                listing.pendingDownloads += 1
                continue
            }
            guard !name.hasPrefix("."), CatalogFile.supportedExtensions.contains(url.pathExtension.lowercased()) else { continue }
            let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .contentModificationDateKey])
            guard values?.isRegularFile == true else { continue }
            let parent = url.deletingLastPathComponent().standardizedFileURL.path
            let folder = parent.hasPrefix(rootPath) ? String(parent.dropFirst(rootPath.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/")) : ""
            listing.files.append(CatalogFile(url: url, modifiedAt: values?.contentModificationDate ?? .distantPast, folder: folder))
        }
        listing.files.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        return listing
    }
}
