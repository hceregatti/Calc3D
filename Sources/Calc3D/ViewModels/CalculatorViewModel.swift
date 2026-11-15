import AppKit
import Calc3DCore
import Observation
import UniformTypeIdentifiers

/// Telas disponíveis na barra lateral.
enum Screen: String, CaseIterable, Identifiable {
    case printJob
    case quotes
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .printJob: "Impressão"
        case .quotes: "Orçamentos"
        case .settings: "Parâmetros fixos"
        }
    }

    var subtitle: String {
        switch self {
        case .printJob: "Dados da peça e resultado"
        case .quotes: "Histórico salvo"
        case .settings: "Máquina, energia, custos e taxas"
        }
    }

    var systemImage: String {
        switch self {
        case .printJob: "cube"
        case .quotes: "doc.text"
        case .settings: "slider.horizontal.3"
        }
    }
}

@MainActor
@Observable
final class CalculatorViewModel {

    /// Tela selecionada na barra lateral.
    var screen: Screen? = .printJob

    /// Registro selecionado na tela de histórico.
    var selectedQuoteID: UUID?
    var quotePendingDeletionID: UUID?

    /// Parâmetros fixos, compartilhados entre todas as impressões.
    var settings: ShopSettings {
        didSet {
            guard settings != oldValue else { return }
            settingsFeedback = nil
            recalculate()
        }
    }

    private(set) var lastSavedSettings: ShopSettings
    var settingsHaveUnsavedChanges: Bool { settings != lastSavedSettings }

    /// Dados da impressão atual.
    var job: PrintJob {
        didSet {
            guard job != oldValue else { return }
            if job.partWeight != oldValue.partWeight { importedWeightNeedsInput = false }
            if job.printHours != oldValue.printHours || job.printMinutes != oldValue.printMinutes {
                importedTimeNeedsInput = false
            }
            if importFeedback?.hasPrefix("Arquivo importado;") == true || importFeedback?.hasPrefix("Dados do fatiador") == true {
                refreshImportFeedback()
            }
            store.save(job)
            recalculate()
        }
    }

    private(set) var result: CostResult
    private(set) var copyFeedback: String?
    private(set) var quoteFeedback: String?
    private(set) var quotes: [QuoteRecord]
    private(set) var importFeedback: String?
    private(set) var settingsFeedback: String?
    private(set) var isImportingModel = false
    private(set) var importedWeightNeedsInput = false
    private(set) var importedTimeNeedsInput = false

    @ObservationIgnored private let store: ParametersStore
    @ObservationIgnored private let quotesStore: QuotesStore

    init(store: ParametersStore = ParametersStore(), quotesStore: QuotesStore = QuotesStore()) {
        self.store = store
        self.quotesStore = quotesStore
        let settings = store.loadSettings()
        let job = store.loadJob()
        self.settings = settings
        self.lastSavedSettings = settings
        self.job = job
        self.result = CostCalculator.calculate(settings: settings, job: job)
        self.quotes = quotesStore.load()
    }

    /// Começa uma nova impressão com os valores padrão, mantendo os parâmetros fixos.
    func newJob() {
        importFeedback = nil
        importedWeightNeedsInput = false
        importedTimeNeedsInput = false
        job = .defaults
        screen = .printJob
    }

    func resetSettings() {
        settings = .defaults
    }

    func saveSettings() {
        guard settingsHaveUnsavedChanges else { return }
        store.save(settings)
        lastSavedSettings = settings
        settingsFeedback = "Parâmetros salvos ✔"
    }

    func saveQuote() {
        let quote = QuoteRecord(job: job, settings: settings, result: result)
        quotes.insert(quote, at: 0)
        quotesStore.save(quotes)
        selectedQuoteID = quote.id
        showQuoteFeedback("Orçamento salvo ✔")
    }

    func deleteQuote(_ quote: QuoteRecord) {
        quotes.removeAll { $0.id == quote.id }
        quotesStore.save(quotes)
        if selectedQuoteID == quote.id {
            selectedQuoteID = quotes.first?.id
        }
    }

    /// Reutiliza os dados da peça, sem substituir os parâmetros fixos atuais.
    func useQuoteAsBase(_ quote: QuoteRecord) {
        importFeedback = nil
        importedWeightNeedsInput = false
        importedTimeNeedsInput = false
        job = quote.job
        screen = .printJob
    }

    func importModel() {
        let panel = NSOpenPanel()
        panel.title = "Importar modelo 3D"
        let modelTypes: [UTType] = ["stl", "3mf"].compactMap { extensionName in
            UTType(filenameExtension: extensionName)
        }
        panel.allowedContentTypes = modelTypes
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }

        isImportingModel = true
        importFeedback = nil
        Task { @MainActor [weak self] in
            do {
                let data = try await Task.detached(priority: .userInitiated) {
                    try ModelFileImporter.importFile(at: url)
                }.value
                guard let self else { return }
                self.isImportingModel = false
                self.applyImportedModel(data)
            } catch {
                guard let self else { return }
                self.isImportingModel = false
                self.importFeedback = error.localizedDescription
            }
        }
    }

    func applyImportedModel(_ data: ImportedModelData) {
        importFeedback = nil
        var importedJob = job
        importedJob.name = data.name
        if let weight = data.weightGrams {
            importedJob.partWeight = weight
        } else {
            importedJob.partWeight = 0
        }
        if let seconds = data.durationSeconds, seconds > 0 {
            let totalMinutes = seconds / 60
            importedJob.printHours = floor(totalMinutes / 60)
            importedJob.printMinutes = totalMinutes.truncatingRemainder(dividingBy: 60)
        } else {
            importedJob.printHours = 0
            importedJob.printMinutes = 0
        }
        job = importedJob
        importedWeightNeedsInput = data.weightGrams == nil
        importedTimeNeedsInput = data.durationSeconds == nil || data.durationSeconds == 0

        refreshImportFeedback()
    }

    private func refreshImportFeedback() {
        let missing = [
            importedWeightNeedsInput ? "peso" : nil,
            importedTimeNeedsInput ? "tempo de impressão" : nil,
        ].compactMap { $0 }
        importFeedback = missing.isEmpty
            ? "Dados importados. Revise os valores antes de calcular."
            : "Arquivo importado; preencha: " + missing.joined(separator: " e ") + "."
    }

    func copySummary() {
        let text = QuoteSummary.text(for: result, job: job)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        showCopyFeedback("Orçamento copiado ✔")
    }

    private func recalculate() {
        result = CostCalculator.calculate(settings: settings, job: job)
    }

    private func showCopyFeedback(_ message: String) {
        copyFeedback = message
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            self?.copyFeedback = nil
        }
    }

    private func showQuoteFeedback(_ message: String) {
        quoteFeedback = message
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            self?.quoteFeedback = nil
        }
    }
}
