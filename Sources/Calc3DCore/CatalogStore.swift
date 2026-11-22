import Foundation

public enum CatalogError: Error, Equatable, Sendable {
    /// Só o autor pode alterar ou remover a própria peça.
    case notAuthor
    case folderUnavailable
}

/// Modelo 3D (3MF/STL) solto na pasta do catálogo, sem cálculo publicado (ex.: enviado pelo celular).
public struct CatalogFile: Identifiable, Equatable, Sendable {
    public var url: URL
    public var modifiedAt: Date
    public var id: String { url.path }
    public var name: String { url.deletingPathExtension().lastPathComponent }
    public var fileExtension: String { url.pathExtension.lowercased() }

    public init(url: URL, modifiedAt: Date) {
        self.url = url
        self.modifiedAt = modifiedAt
    }

    public static let supportedExtensions: Set<String> = ["3mf", "stl"]
}

/// Conteúdo lido do catálogo.
public struct CatalogListing: Sendable {
    public var entries: [CatalogEntry] = []
    /// Modelos 3D soltos na pasta, que ainda não têm cálculo publicado.
    public var files: [CatalogFile] = []
    /// Arquivos ilegíveis ou de versão mais nova, ignorados.
    public var skipped: [String] = []
    /// Arquivos da nuvem ainda não baixados (entram na próxima atualização).
    public var pendingDownloads = 0

    public init() {}
}

/// Acesso ao catálogo; a pasta é o primeiro backend e um banco poderia ser outro.
public protocol CatalogStoring: Sendable {
    func list() throws -> CatalogListing
    /// Publica ou atualiza; recusa se a entrada existente é de outro autor.
    func publish(_ entry: CatalogEntry) throws
    /// Remove só se `authorID` for o autor da entrada.
    func remove(id: UUID, authorID: UUID) throws
}

/// Catálogo em pasta compartilhada (iCloud Drive, Drive, Dropbox, rede…): um JSON por peça.
/// Como cada arquivo só é escrito pelo autor, não há conflito entre usuários.
public struct FolderCatalogStore: CatalogStoring {
    public static let folderName = "Calc3D-Catalogo"

    public let root: URL

    public init(root: URL) { self.root = root }

    private var entriesDirectory: URL {
        root.appendingPathComponent(Self.folderName, isDirectory: true).appendingPathComponent("entries", isDirectory: true)
    }

    private func fileURL(for id: UUID) -> URL {
        entriesDirectory.appendingPathComponent("\(id.uuidString).json")
    }

    private static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }

    private static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    public func list() throws -> CatalogListing {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: root.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw CatalogError.folderUnavailable
        }
        var listing = CatalogListing()
        let names = (try? FileManager.default.contentsOfDirectory(atPath: entriesDirectory.path)) ?? []
        for name in names.sorted() {
            // Placeholder do iCloud (".<arquivo>.json.icloud"): pede o download e tenta na próxima vez.
            if name.hasPrefix("."), name.hasSuffix(".json.icloud") {
                let real = String(name.dropFirst().dropLast(".icloud".count))
                try? FileManager.default.startDownloadingUbiquitousItem(at: entriesDirectory.appendingPathComponent(real))
                listing.pendingDownloads += 1
                continue
            }
            guard name.hasSuffix(".json") else { continue }
            let url = entriesDirectory.appendingPathComponent(name)
            guard let data = try? Data(contentsOf: url),
                  let entry = try? Self.decoder().decode(CatalogEntry.self, from: data),
                  entry.schemaVersion <= CatalogEntry.currentSchema
            else {
                listing.skipped.append(name)
                continue
            }
            listing.entries.append(entry)
        }
        listing.entries.sort { $0.updatedAt > $1.updatedAt }
        scanLooseModels(into: &listing)
        return listing
    }

    /// Procura 3MF/STL na pasta escolhida (só no primeiro nível) e dentro de "Calc3D-Catalogo" (em qualquer nível).
    private func scanLooseModels(into listing: inout CatalogListing) {
        let fm = FileManager.default
        let catalogDir = root.appendingPathComponent(Self.folderName, isDirectory: true)
        var found: [URL] = []
        if let top = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) { found += top }
        if let deep = fm.enumerator(at: catalogDir, includingPropertiesForKeys: nil) {
            for case let url as URL in deep where url.deletingLastPathComponent().lastPathComponent != "entries" { found.append(url) }
        }
        var seen = Set<String>()
        for var url in found {
            // Placeholder do iCloud (".<arquivo>.3mf.icloud"): pede o download e mostra na próxima vez.
            let name = url.lastPathComponent
            if name.hasPrefix("."), name.hasSuffix(".icloud") {
                let real = String(name.dropFirst().dropLast(".icloud".count))
                guard CatalogFile.supportedExtensions.contains((real as NSString).pathExtension.lowercased()) else { continue }
                try? fm.startDownloadingUbiquitousItem(at: url.deletingLastPathComponent().appendingPathComponent(real))
                listing.pendingDownloads += 1
                continue
            }
            guard CatalogFile.supportedExtensions.contains(url.pathExtension.lowercased()) else { continue }
            url = url.standardizedFileURL
            guard seen.insert(url.path).inserted else { continue }
            let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .contentModificationDateKey])
            guard values?.isRegularFile == true else { continue }
            listing.files.append(CatalogFile(url: url, modifiedAt: values?.contentModificationDate ?? .distantPast))
        }
        listing.files.sort { $0.modifiedAt > $1.modifiedAt }
    }

    public func publish(_ entry: CatalogEntry) throws {
        guard FileManager.default.fileExists(atPath: root.path) else { throw CatalogError.folderUnavailable }
        let url = fileURL(for: entry.id)
        if let data = try? Data(contentsOf: url), let existing = try? Self.decoder().decode(CatalogEntry.self, from: data),
           existing.authorID != entry.authorID {
            throw CatalogError.notAuthor
        }
        try FileManager.default.createDirectory(at: entriesDirectory, withIntermediateDirectories: true)
        try Self.encoder().encode(entry).write(to: url, options: .atomic)
    }

    public func remove(id: UUID, authorID: UUID) throws {
        let url = fileURL(for: id)
        guard let data = try? Data(contentsOf: url) else { return }
        if let existing = try? Self.decoder().decode(CatalogEntry.self, from: data), existing.authorID != authorID {
            throw CatalogError.notAuthor
        }
        try FileManager.default.removeItem(at: url)
    }
}
