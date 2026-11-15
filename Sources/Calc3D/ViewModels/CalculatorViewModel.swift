import AppKit
import Calc3DCore
import Observation

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

    /// Parâmetros fixos, compartilhados entre todas as impressões.
    var settings: ShopSettings {
        didSet {
            guard settings != oldValue else { return }
            store.save(settings)
            recalculate()
        }
    }

    /// Dados da impressão atual.
    var job: PrintJob {
        didSet {
            guard job != oldValue else { return }
            store.save(job)
            recalculate()
        }
    }

    private(set) var result: CostResult
    private(set) var copyFeedback: String?
    private(set) var quoteFeedback: String?
    private(set) var quotes: [QuoteRecord]

    @ObservationIgnored private let store: ParametersStore
    @ObservationIgnored private let quotesStore: QuotesStore

    init(store: ParametersStore = ParametersStore(), quotesStore: QuotesStore = QuotesStore()) {
        self.store = store
        self.quotesStore = quotesStore
        let settings = store.loadSettings()
        let job = store.loadJob()
        self.settings = settings
        self.job = job
        self.result = CostCalculator.calculate(settings: settings, job: job)
        self.quotes = quotesStore.load()
    }

    /// Começa uma nova impressão com os valores padrão, mantendo os parâmetros fixos.
    func newJob() {
        job = .defaults
        screen = .printJob
    }

    func resetSettings() {
        settings = .defaults
    }

    func saveQuote() {
        let quote = QuoteRecord(job: job, settings: settings, result: result)
        quotes.insert(quote, at: 0)
        quotesStore.save(quotes)
        selectedQuoteID = quote.id
        showQuoteFeedback("Orçamento salvo ✔")
    }

    /// Reutiliza os dados da peça, sem substituir os parâmetros fixos atuais.
    func useQuoteAsBase(_ quote: QuoteRecord) {
        job = quote.job
        screen = .printJob
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
