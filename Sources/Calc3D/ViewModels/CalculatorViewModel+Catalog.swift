import AppKit
import Calc3DCore

extension CalculatorViewModel {
    var isCatalogConfigured: Bool {
        catalogFolderPath != nil && !catalogUserName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var catalogStore: FolderCatalogStore? {
        catalogFolderPath.map { FolderCatalogStore(root: URL(fileURLWithPath: $0, isDirectory: true)) }
    }

    func isMine(_ entry: CatalogEntry) -> Bool { entry.authorID == catalogUserID }

    /// Peça do histórico que já está publicada por mim.
    func catalogEntry(for quote: QuoteRecord) -> CatalogEntry? {
        catalogEntries.first { $0.id == quote.id && isMine($0) }
    }

    /// Entradas visíveis, aplicando o filtro "Minhas" e a busca.
    var visibleCatalogEntries: [CatalogEntry] {
        let query = catalogSearch.trimmingCharacters(in: .whitespaces)
        return catalogEntries.filter { entry in
            if catalogOnlyMine && !isMine(entry) { return false }
            guard !query.isEmpty else { return true }
            return [entry.job.name, entry.authorName, entry.note, entry.job.filamentName ?? ""]
                .contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    func chooseCatalogFolder() {
        let panel = NSOpenPanel()
        panel.title = "Escolher a pasta compartilhada do catálogo"
        panel.message = "Use uma pasta sincronizada (iCloud Drive, Google Drive, Dropbox…) que as outras pessoas também acessem."
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Usar esta pasta"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        catalogFolderPath = url.path
        selectedCatalogEntryID = nil
        refreshCatalog()
    }

    func disconnectCatalog() {
        catalogFolderPath = nil
        catalogEntries = []
        selectedCatalogEntryID = nil
        catalogMessage = nil
    }

    /// Relê a pasta; chamado ao abrir a aba, ao voltar para o app e no botão.
    func refreshCatalog() {
        guard let store = catalogStore else { return }
        isRefreshingCatalog = true
        defer { isRefreshingCatalog = false }
        do {
            let listing = try store.list()
            catalogEntries = listing.entries
            if let id = selectedCatalogEntryID, !listing.entries.contains(where: { $0.id == id }) {
                selectedCatalogEntryID = nil
            }
            var notes: [String] = []
            if !listing.skipped.isEmpty {
                notes.append("\(listing.skipped.count) arquivo(s) ignorado(s) por estarem ilegíveis ou virem de uma versão mais nova.")
            }
            if listing.pendingDownloads > 0 {
                notes.append("\(listing.pendingDownloads) peça(s) ainda sendo baixada(s) da nuvem; atualize em instantes.")
            }
            catalogMessage = notes.isEmpty ? nil : notes.joined(separator: " ")
        } catch {
            catalogMessage = "Não foi possível abrir a pasta do catálogo. Ela existe e está acessível?"
        }
    }

    func refreshCatalogIfConfigured() {
        if isCatalogConfigured { refreshCatalog() }
    }

    /// Publica (ou atualiza) as peças escolhidas. Retorna quantas foram publicadas.
    @discardableResult
    func publishToCatalog(_ quotes: [QuoteRecord]) -> Int {
        guard isCatalogConfigured, let store = catalogStore else {
            screen = .catalog
            catalogMessage = "Escolha a pasta e informe seu nome para publicar peças."
            return 0
        }
        var published = 0
        let name = catalogUserName.trimmingCharacters(in: .whitespaces)
        for quote in quotes {
            let previous = catalogEntry(for: quote)
            let entry = CatalogEntry(
                id: quote.id, authorID: catalogUserID, authorName: name, note: previous?.note ?? "",
                job: quote.job, settings: quote.settings, result: quote.result,
                publishedAt: previous?.publishedAt ?? .now, updatedAt: .now
            )
            do {
                try store.publish(entry)
                published += 1
            } catch {
                catalogMessage = "Não foi possível publicar \"\(quote.job.name)\": \(describe(error))"
            }
        }
        refreshCatalog()
        if published > 0 {
            showQuoteFeedback(published == 1 ? "Peça publicada no catálogo ✔" : "\(published) peças publicadas no catálogo ✔")
        }
        return published
    }

    func retractFromCatalog(_ ids: [UUID]) {
        guard let store = catalogStore else { return }
        for id in ids {
            do { try store.remove(id: id, authorID: catalogUserID) } catch {
                catalogMessage = describe(error)
            }
        }
        if let selected = selectedCatalogEntryID, ids.contains(selected) { selectedCatalogEntryID = nil }
        refreshCatalog()
    }

    /// Atualiza a nota que acompanha uma peça minha publicada.
    func updateCatalogNote(_ note: String, for entry: CatalogEntry) {
        guard isMine(entry), entry.note != note, let store = catalogStore else { return }
        var updated = entry
        updated.note = note
        updated.updatedAt = .now
        do {
            try store.publish(updated)
            if let index = catalogEntries.firstIndex(where: { $0.id == entry.id }) { catalogEntries[index] = updated }
        } catch {
            catalogMessage = describe(error)
        }
    }

    /// Abre a peça em "Calcular peça" com os meus parâmetros fixos.
    func useCatalogEntryAsBase(_ entry: CatalogEntry) {
        calculator.load(entry.localJob)
        screen = .printJob
    }

    /// Guarda uma cópia da peça no meu histórico, calculada com os meus parâmetros.
    func saveCatalogEntryCopy(_ entry: CatalogEntry) {
        let job = entry.localJob
        addQuoteToHistory(QuoteRecord(job: job, settings: settings, result: CostCalculator.calculate(settings: settings, job: job)))
        catalogMessage = "Cópia salva no seu histórico de peças ✔"
    }

    private func describe(_ error: Error) -> String {
        switch error as? CatalogError {
        case .notAuthor: "só quem publicou pode alterar ou remover esta peça."
        case .folderUnavailable: "a pasta do catálogo não está acessível."
        case nil: error.localizedDescription
        }
    }
}
