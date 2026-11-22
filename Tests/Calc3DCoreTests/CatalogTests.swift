import Testing
import Foundation
@testable import Calc3DCore

@Suite struct CatalogTests {
    private func entry(author: UUID = UUID(), name: String = "Ana", id: UUID = UUID(), settings: ShopSettings = .defaults) -> CatalogEntry {
        var job = PrintJob.defaults
        job.name = "Suporte"
        job.filamentID = UUID(); job.filamentName = "PLA Preto"; job.filamentPricePerGram = ShopSettings.defaults.filamentPricePerGram
        return CatalogEntry(id: id, authorID: author, authorName: name, note: "ok", job: job, settings: settings,
                            result: CostCalculator.calculate(settings: settings, job: job))
    }

    private func tempFolder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("catalogo-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func publicaELista() throws {
        let store = FolderCatalogStore(root: try tempFolder())
        let e = entry()
        try store.publish(e)
        let listing = try store.list()
        #expect(listing.entries.count == 1)
        #expect(listing.entries[0].id == e.id && listing.entries[0].job.name == "Suporte")
        #expect(listing.entries[0].result == e.result)
    }

    @Test func publicarDeNovoAtualizaAMesmaEntrada() throws {
        let store = FolderCatalogStore(root: try tempFolder())
        var e = entry()
        try store.publish(e)
        e.note = "novo"
        try store.publish(e)
        let listing = try store.list()
        #expect(listing.entries.count == 1 && listing.entries[0].note == "novo")
    }

    @Test func soOAutorAlteraOuRemove() throws {
        let store = FolderCatalogStore(root: try tempFolder())
        let mine = entry()
        try store.publish(mine)
        var hijack = mine; hijack.authorID = UUID()
        #expect(throws: CatalogError.notAuthor) { try store.publish(hijack) }
        #expect(throws: CatalogError.notAuthor) { try store.remove(id: mine.id, authorID: UUID()) }
        #expect(try store.list().entries.count == 1)
        try store.remove(id: mine.id, authorID: mine.authorID)
        #expect(try store.list().entries.isEmpty)
    }

    @Test func ignoraArquivoCorrompidoEVersaoFutura() throws {
        let root = try tempFolder()
        let store = FolderCatalogStore(root: root)
        let good = entry()
        try store.publish(good)
        let dir = root.appendingPathComponent(FolderCatalogStore.folderName).appendingPathComponent("entries")
        try Data("{ não é json".utf8).write(to: dir.appendingPathComponent("quebrado.json"))
        var future = entry(); future.schemaVersion = 99
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(future).write(to: dir.appendingPathComponent("\(future.id.uuidString).json"))
        let listing = try store.list()
        #expect(listing.entries.map(\.id) == [good.id])
        #expect(listing.skipped.count == 2)
    }

    @Test func pastaInexistente() {
        let store = FolderCatalogStore(root: URL(fileURLWithPath: "/nao/existe/\(UUID().uuidString)"))
        #expect(throws: CatalogError.folderUnavailable) { try store.list() }
        #expect(throws: CatalogError.folderUnavailable) { try store.publish(entry()) }
    }

    @Test func comparaPrecoComOsMeusParametros() {
        var authorSettings = ShopSettings.defaults
        authorSettings.laborRate = 10
        var mine = ShopSettings.defaults
        mine.laborRate = 60
        let e = entry(settings: authorSettings)
        let cmp = e.comparison(with: mine)
        #expect(cmp.authorPrice == e.result.suggestedPrice)
        #expect((cmp.priceDelta ?? 0) > 0)
        // O filamento do autor não vale para mim: usa o padrão dos meus parâmetros.
        #expect(e.localJob.filamentPricePerGram == nil && e.localJob.filamentID == nil)
    }

    @Test func decodificacaoTolerante() throws {
        let e = entry()
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        var object = try JSONSerialization.jsonObject(with: encoder.encode(e)) as! [String: Any]
        object.removeValue(forKey: "note"); object.removeValue(forKey: "updatedAt"); object["campoNovo"] = 1
        let data = try JSONSerialization.data(withJSONObject: object)
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let back = try decoder.decode(CatalogEntry.self, from: data)
        #expect(back.note == "" && back.updatedAt == back.publishedAt)
    }
}
