import AppKit
import Calc3DCore

/// O que foi possível ler de um modelo do catálogo.
enum CatalogFileInfo {
    case loaded(ImportedModelData)
    case failed(String)
}

extension CalculatorViewModel {
    var isCatalogConfigured: Bool { catalogFolderPath != nil }

    private var catalogStore: FolderCatalogStore? {
        catalogFolderPath.map { FolderCatalogStore(root: URL(fileURLWithPath: $0, isDirectory: true)) }
    }

    var visibleCatalogFiles: [CatalogFile] {
        let query = catalogSearch.trimmingCharacters(in: .whitespaces)
        return catalogFiles.filter {
            query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) || $0.folder.localizedCaseInsensitiveContains(query)
        }
    }

    func chooseCatalogFolder() {
        let panel = NSOpenPanel()
        panel.title = "Escolher a pasta do catálogo"
        panel.message = "Pasta com os arquivos 3MF/STL já configurados, compartilhada (iCloud Drive, Google Drive, Dropbox…) com as outras pessoas."
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Usar esta pasta"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        catalogFolderPath = url.path
        selectedCatalogFileID = nil
        catalogFileInfo = [:]
        refreshCatalog()
    }

    func disconnectCatalog() {
        catalogFolderPath = nil
        catalogFiles = []
        selectedCatalogFileID = nil
        catalogFileInfo = [:]
        catalogMessage = nil
    }

    /// Relê a pasta; chamado ao abrir a aba, ao voltar para o app e no botão.
    func refreshCatalog() {
        guard let store = catalogStore else { return }
        isRefreshingCatalog = true
        defer { isRefreshingCatalog = false }
        do {
            let listing = try store.list()
            catalogFiles = listing.files
            if let id = selectedCatalogFileID, !listing.files.contains(where: { $0.id == id }) {
                selectedCatalogFileID = nil
            }
            // Arquivos que mudaram precisam ser lidos de novo.
            catalogFileInfo = catalogFileInfo.filter { key, _ in listing.files.contains { $0.id == key } }
            catalogMessage = listing.pendingDownloads > 0
                ? "\(listing.pendingDownloads) arquivo(s) ainda sendo baixado(s) da nuvem; atualize em instantes."
                : nil
        } catch {
            catalogMessage = "Não foi possível abrir a pasta do catálogo. Ela existe e está acessível?"
        }
    }

    func refreshCatalogIfConfigured() {
        if isCatalogConfigured { refreshCatalog() }
    }

    /// Lê peso e tempo gravados no arquivo (uma vez por arquivo, em segundo plano).
    func loadCatalogFileInfo(_ file: CatalogFile) {
        guard catalogFileInfo[file.id] == nil else { return }
        let url = file.url, id = file.id
        Task { @MainActor [weak self] in
            let info: CatalogFileInfo
            do {
                info = .loaded(try await Task.detached(priority: .userInitiated) {
                    try ModelFileImporter.importFile(at: url)
                }.value)
            } catch {
                info = .failed(error.localizedDescription)
            }
            self?.catalogFileInfo[id] = info
        }
    }

    /// Peça calculada com os meus parâmetros a partir do que o arquivo traz; nil se faltar peso ou tempo.
    func catalogJob(for file: CatalogFile) -> PrintJob? {
        guard case .loaded(let data)? = catalogFileInfo[file.id],
              let weight = data.weightGrams, let seconds = data.durationSeconds, seconds > 0 else { return nil }
        var job = calculator.job
        job.name = data.name
        job.partWeight = weight
        let totalMinutes = seconds / 60
        job.printHours = floor(totalMinutes / 60)
        job.printMinutes = totalMinutes.truncatingRemainder(dividingBy: 60)
        return job
    }

    /// Abre o modelo em "Calcular peça" com os meus parâmetros fixos.
    func openCatalogFileInCalculator(_ file: CatalogFile) {
        guard case .loaded(let data)? = catalogFileInfo[file.id] else { return }
        calculator.load(calculator.job)
        calculator.applyImportedModel(data)
        screen = .printJob
    }

    /// Guarda no meu histórico a peça calculada com os meus parâmetros.
    func saveCatalogFileToHistory(_ file: CatalogFile) {
        guard let job = catalogJob(for: file) else { return }
        addQuoteToHistory(QuoteRecord(job: job, settings: settings, result: CostCalculator.calculate(settings: settings, job: job)))
        catalogMessage = "Peça salva no seu histórico ✔"
    }

    func revealCatalogFile(_ file: CatalogFile) {
        NSWorkspace.shared.activateFileViewerSelecting([file.url])
    }
}
