import AppKit
import UniformTypeIdentifiers
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
            catalogThumbnails = catalogThumbnails.filter { key, _ in listing.files.contains { $0.id == key } }
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

    /// Carrega a imagem do modelo (embutida no 3MF ou gerada pelo Quick Look), uma vez por arquivo.
    func loadCatalogThumbnail(_ file: CatalogFile) {
        guard catalogThumbnails[file.id] == nil, catalogThumbnailRequests.insert(file.id).inserted else { return }
        let url = file.url, id = file.id
        Task { @MainActor [weak self] in
            let data = await Task.detached(priority: .utility) { CatalogThumbnail.embeddedImageData(in: url) }.value
            var image = data.flatMap { NSImage(data: $0) }
            if image == nil { image = await CatalogThumbnail.quickLookImage(for: url) }
            guard let self else { return }
            if let image { self.catalogThumbnails[id] = image }
            self.catalogThumbnailRequests.remove(id)
        }
    }

    /// Dados do arquivo já com a mesa escolhida (quando há várias); nil se ainda não leu ou falhou.
    func catalogData(for file: CatalogFile) -> ImportedModelData? {
        guard case .loaded(let data)? = catalogFileInfo[file.id] else { return nil }
        guard data.plates.count > 1 else { return data }
        let wanted = catalogPlateChoice[file.id] ?? data.plates[0].index
        return data.selecting(data.plates.first { $0.index == wanted } ?? data.plates[0])
    }

    /// Peça calculada com os meus parâmetros a partir do que o arquivo traz; nil se faltar peso ou tempo.
    func catalogJob(for file: CatalogFile) -> PrintJob? {
        guard let data = catalogData(for: file),
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
        guard let data = catalogData(for: file) else { return }
        calculator.load(calculator.job)
        calculator.applyImportedModel(data)
        screen = .printJob
    }

    /// Envia arquivos 3MF/STL do computador para a pasta do catálogo, sem sobrescrever nenhum existente.
    func uploadToCatalog() {
        guard let folder = catalogFolderPath else { return }
        let panel = NSOpenPanel()
        panel.title = "Enviar modelos para o catálogo"
        panel.prompt = "Enviar"
        panel.allowedContentTypes = CatalogFile.supportedExtensions.sorted().compactMap { UTType(filenameExtension: $0) }
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK else { return }

        let fm = FileManager.default
        let root = URL(fileURLWithPath: folder, isDirectory: true)
        var sent = 0
        var failures: [String] = []
        var lastSent: URL?
        for source in panel.urls {
            var target = root.appendingPathComponent(source.lastPathComponent)
            var counter = 2
            while fm.fileExists(atPath: target.path) {
                let base = source.deletingPathExtension().lastPathComponent
                target = root.appendingPathComponent("\(base) \(counter).\(source.pathExtension)")
                counter += 1
            }
            do {
                try fm.copyItem(at: source, to: target)
                sent += 1
                lastSent = target
            } catch {
                failures.append("\(source.lastPathComponent): \(error.localizedDescription)")
            }
        }
        refreshCatalog()
        if sent == 1, let lastSent { selectedCatalogFileID = lastSent.standardizedFileURL.path }
        var parts: [String] = []
        if sent > 0 { parts.append(sent == 1 ? "1 arquivo enviado ao catálogo ✔" : "\(sent) arquivos enviados ao catálogo ✔") }
        if !failures.isEmpty { parts.append("Falhou: " + failures.joined(separator: "; ")) }
        catalogMessage = parts.joined(separator: " ")
    }

    /// Abre uma cópia do modelo no fatiador. A cópia fica em pasta temporária para que alterações no fatiador
    /// não mexam no arquivo compartilhado do catálogo.
    func openCatalogFile(_ file: CatalogFile, in slicer: Slicer) {
        guard let app = slicer.applicationURL else {
            catalogMessage = "\(slicer.title) não foi encontrado em Aplicativos. Instale-o para abrir o modelo nele."
            return
        }
        let fm = FileManager.default
        let folder = fm.temporaryDirectory.appending(path: "Calc3D-Fatiador/\(UUID().uuidString)", directoryHint: .isDirectory)
        let copy = folder.appending(path: file.url.lastPathComponent)
        do {
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
            try fm.copyItem(at: file.url, to: copy)
        } catch {
            catalogMessage = "Não foi possível preparar \"\(file.name)\": \(error.localizedDescription)"
            return
        }
        NSWorkspace.shared.open([copy], withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration()) { [weak self] _, error in
            guard let error else { return }
            Task { @MainActor in
                self?.catalogMessage = "Não foi possível abrir no \(slicer.title): \(error.localizedDescription)"
            }
        }
    }

    /// Salva uma cópia do arquivo do catálogo no computador.
    func downloadCatalogFile(_ file: CatalogFile) {
        let panel = NSSavePanel()
        panel.title = "Baixar modelo do catálogo"
        panel.nameFieldStringValue = file.url.lastPathComponent
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        let fm = FileManager.default
        do {
            if fm.fileExists(atPath: destination.path) { try fm.removeItem(at: destination) }
            try fm.copyItem(at: file.url, to: destination)
            catalogMessage = "\"\(file.url.lastPathComponent)\" baixado ✔"
        } catch {
            catalogMessage = "Não foi possível baixar \"\(file.name)\": \(error.localizedDescription)"
        }
    }

    /// Guarda no meu histórico a peça calculada com os meus parâmetros.
    func saveCatalogFileToHistory(_ file: CatalogFile) {
        guard let job = catalogJob(for: file) else { return }
        addQuoteToHistory(QuoteRecord(job: job, settings: settings, result: CostCalculator.calculate(settings: settings, job: job)))
        catalogMessage = "Peça salva no seu histórico ✔"
    }

    /// Move o arquivo para a Lixeira (recuperável). Como a pasta é compartilhada, some para todos que a usam.
    func deleteCatalogFile(_ file: CatalogFile) {
        do {
            try FileManager.default.trashItem(at: file.url, resultingItemURL: nil)
            catalogMessage = "\"\(file.url.lastPathComponent)\" movido para a Lixeira ✔"
        } catch {
            catalogMessage = "Não foi possível excluir \"\(file.name)\": \(error.localizedDescription)"
        }
        if selectedCatalogFileID == file.id { selectedCatalogFileID = nil }
        catalogFileInfo[file.id] = nil
        catalogThumbnails[file.id] = nil
        refreshCatalogKeepingMessage()
    }

    private func refreshCatalogKeepingMessage() {
        let message = catalogMessage
        refreshCatalog()
        if let message { catalogMessage = [message, catalogMessage].compactMap { $0 }.joined(separator: " ") }
    }

    func revealCatalogFile(_ file: CatalogFile) {
        NSWorkspace.shared.activateFileViewerSelecting([file.url])
    }
}
