import Testing
import Foundation
@testable import Calc3DCore

@Suite struct CatalogTests {
    private func tempFolder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("catalogo-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func listaModelosDaPastaEDasSubpastas() throws {
        let root = try tempFolder()
        let sub = root.appendingPathComponent("Suportes", isDirectory: true)
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        try Data([1]).write(to: root.appendingPathComponent("Celular.3MF"))
        try Data([1]).write(to: sub.appendingPathComponent("Vaso.stl"))
        try Data([1]).write(to: sub.appendingPathComponent("nota.txt"))
        let listing = try FolderCatalogStore(root: root).list()
        #expect(listing.files.map(\.name) == ["Celular", "Vaso"])
        #expect(listing.files.map(\.folder) == ["", "Suportes"])
        #expect(listing.files.map(\.fileExtension) == ["3mf", "stl"])
    }

    @Test func ignoraOcultosEOutrosFormatos() throws {
        let root = try tempFolder()
        try Data([1]).write(to: root.appendingPathComponent(".oculto.3mf"))
        try Data([1]).write(to: root.appendingPathComponent("foto.png"))
        let listing = try FolderCatalogStore(root: root).list()
        #expect(listing.files.isEmpty && listing.pendingDownloads == 0)
    }

    @Test func pastaInexistenteDaErro() {
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent("nao-existe-\(UUID().uuidString)")
        #expect(throws: CatalogError.folderUnavailable) { try FolderCatalogStore(root: missing).list() }
    }
}
