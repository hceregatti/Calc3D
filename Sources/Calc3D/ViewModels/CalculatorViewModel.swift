import AppKit
import Calc3DCore
import Observation
import UniformTypeIdentifiers

/// Telas disponíveis na barra lateral.
enum Screen: String, CaseIterable, Identifiable {
    case home
    case printJob
    case parts
    case proposals
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Início"
        case .printJob: "Calcular peça"
        case .parts: "Peças"
        case .proposals: "Orçamentos"
        case .settings: "Parâmetros fixos"
        }
    }

    var subtitle: String {
        switch self {
        case .home: "Visão geral e atalhos"
        case .printJob: "Dados da impressão e preço"
        case .parts: "Histórico de cálculos de peças"
        case .proposals: "Orçamentos com várias peças"
        case .settings: "Máquina, energia, custos e taxas"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house"
        case .printJob: "function"
        case .parts: "cube.box"
        case .proposals: "doc.text"
        case .settings: "slider.horizontal.3"
        }
    }
}

private enum ProposalDraftAction {
    case create
    case open(UUID)
    case addCalculations([QuoteRecord], proposalID: UUID?)
}

@MainActor
@Observable
final class CalculatorViewModel {

    /// Tela selecionada na barra lateral.
    var screen: Screen? = .home

    /// Peças selecionadas no histórico (permite seleção múltipla).
    var selectedQuoteIDs: Set<UUID> = []
    var quotePendingDeletionID: UUID?
    var quoteNameDraftID: UUID?
    var quoteNameDraft = ""

    /// Orçamento selecionado na tela de orçamentos.
    var selectedProposalID: UUID?
    var proposalDraft: ProposalRecord?
    var proposalPendingDeletionID: UUID?
    var isConfirmingProposalDiscard = false

    /// Seletor de peças do histórico no editor de orçamento.
    var isPickingParts = false {
        didSet {
            guard isPickingParts != oldValue else { return }
            partsPickerSelection = []
            partsPickerSearch = ""
        }
    }
    var partsPickerSelection: Set<UUID> = []
    var partsPickerSearch = ""
    private var pendingProposalDraftAction: ProposalDraftAction?

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
    var proposalHasUnsavedChanges: Bool {
        guard let proposalDraft else { return false }
        guard let saved = proposals.first(where: { $0.id == proposalDraft.id }) else { return true }
        return proposalDraft != saved
    }

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
    private(set) var proposalPDFFeedback: String?
    private(set) var quotes: [QuoteRecord]
    private(set) var proposals: [ProposalRecord]
    private(set) var importFeedback: String?
    private(set) var settingsFeedback: String?
    private(set) var isImportingModel = false
    private(set) var importedWeightNeedsInput = false
    private(set) var importedTimeNeedsInput = false

    @ObservationIgnored private let store: ParametersStore
    @ObservationIgnored private let quotesStore: QuotesStore
    @ObservationIgnored private let proposalsStore: ProposalsStore

    init(
        store: ParametersStore = ParametersStore(),
        quotesStore: QuotesStore = QuotesStore(),
        proposalsStore: ProposalsStore = ProposalsStore()
    ) {
        self.store = store
        self.quotesStore = quotesStore
        self.proposalsStore = proposalsStore
        let settings = store.loadSettings()
        let job = store.loadJob()
        self.settings = settings
        self.lastSavedSettings = settings
        self.job = job
        self.result = CostCalculator.calculate(settings: settings, job: job)
        self.quotes = quotesStore.load()
        self.proposals = proposalsStore.load()
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
        selectedQuoteIDs = [quote.id]
        showQuoteFeedback("Peça salva no histórico ✔")
    }

    func deleteQuote(_ quote: QuoteRecord) {
        quotes.removeAll { $0.id == quote.id }
        quotesStore.save(quotes)
        selectedQuoteIDs.remove(quote.id)
    }

    func updateQuoteNameDraft(_ name: String, for quoteID: UUID) {
        quoteNameDraftID = quoteID
        quoteNameDraft = name
    }

    func quoteNameHasUnsavedChanges(for quote: QuoteRecord) -> Bool {
        guard quoteNameDraftID == quote.id else { return false }
        let name = quoteNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        return !name.isEmpty && name != quote.job.name
    }

    func saveQuoteName(for quote: QuoteRecord) {
        let name = quoteNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty,
              let index = quotes.firstIndex(where: { $0.id == quote.id })
        else { return }

        var renamedJob = quote.job
        renamedJob.name = name
        quotes[index] = QuoteRecord(
            id: quote.id,
            savedAt: quote.savedAt,
            job: renamedJob,
            settings: quote.settings,
            result: quote.result
        )
        quotesStore.save(quotes)
        quoteNameDraftID = quote.id
        quoteNameDraft = name
    }

    func saveProposal(_ proposal: ProposalRecord) {
        var proposal = proposal
        proposal.updatedAt = .now
        if let index = proposals.firstIndex(where: { $0.id == proposal.id }) {
            proposals[index] = proposal
        } else {
            proposals.insert(proposal, at: 0)
        }
        proposals.sort { $0.updatedAt > $1.updatedAt }
        proposalsStore.save(proposals)
        selectedProposalID = proposal.id
    }

    func requestNewProposalDraft() {
        guard proposalHasUnsavedChanges else {
            createProposalDraft()
            return
        }
        pendingProposalDraftAction = .create
        isConfirmingProposalDiscard = true
    }

    func requestOpenProposal(_ id: UUID) {
        guard proposalDraft?.id != id else { return }
        guard proposalHasUnsavedChanges else {
            openProposalDraft(id)
            return
        }
        pendingProposalDraftAction = .open(id)
        isConfirmingProposalDiscard = true
        selectedProposalID = proposalDraft?.id
    }

    func confirmDiscardProposalDraft() {
        isConfirmingProposalDiscard = false
        guard let action = pendingProposalDraftAction else { return }
        pendingProposalDraftAction = nil
        switch action {
        case .create:
            createProposalDraft()
        case .open(let id):
            openProposalDraft(id)
        case .addCalculations(let calculations, let proposalID):
            appendCalculationsToProposal(calculations, proposalID: proposalID)
        }
    }

    func cancelDiscardProposalDraft() {
        isConfirmingProposalDiscard = false
        pendingProposalDraftAction = nil
        selectedProposalID = proposalDraft?.id
    }

    func createProposalDraft() {
        let proposal = ProposalRecord(title: "Novo orçamento")
        proposalDraft = proposal
        selectedProposalID = proposal.id
    }

    func updateProposalDraft(_ update: (inout ProposalRecord) -> Void) {
        guard var proposal = proposalDraft else { return }
        update(&proposal)
        proposalDraft = proposal
    }

    func addManualItemToDraft() {
        updateProposalDraft { proposal in
            proposal.items.append(ProposalItem(name: "Novo produto", unitPrice: 0))
        }
    }

    /// Adiciona peças do histórico ao orçamento em edição.
    func addQuotesToDraft(_ quotes: [QuoteRecord]) {
        let items = quotes.compactMap(proposalItem(for:))
        guard !items.isEmpty else { return }
        updateProposalDraft { $0.items.append(contentsOf: items) }
    }

    /// Peças do histórico, na ordem da lista, que podem entrar em um orçamento.
    func quotes(withIDs ids: Set<UUID>) -> [QuoteRecord] {
        quotes.filter { ids.contains($0.id) }
    }

    static func canAddToProposal(_ quote: QuoteRecord) -> Bool {
        quote.result.suggestedPrice.map { $0.isFinite && $0 >= 0 } ?? false
    }

    /// Cria um orçamento novo (proposalID nil) ou adiciona a um existente.
    func addQuotesToProposal(_ quotes: [QuoteRecord], proposalID: UUID?) {
        let calculations = quotes.filter(Self.canAddToProposal)
        guard !calculations.isEmpty else { return }
        guard proposalHasUnsavedChanges else {
            appendCalculationsToProposal(calculations, proposalID: proposalID)
            return
        }
        pendingProposalDraftAction = .addCalculations(calculations, proposalID: proposalID)
        isConfirmingProposalDiscard = true
    }

    func addCurrentCalculationToProposal(_ proposalID: UUID?) {
        // Cálculo avulso: não fica vinculado a um registro do histórico.
        let calculation = QuoteRecord(job: job, settings: settings, result: result)
        addQuotesToProposal([calculation], proposalID: proposalID)
    }

    private func proposalItem(for quote: QuoteRecord) -> ProposalItem? {
        guard Self.canAddToProposal(quote), let price = quote.result.suggestedPrice else { return nil }
        let name = quote.job.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return ProposalItem(
            name: name.isEmpty ? "Peça sem nome" : name,
            unitPrice: price,
            sourceQuoteID: quotes.contains { $0.id == quote.id } ? quote.id : nil
        )
    }

    private func appendCalculationsToProposal(_ calculations: [QuoteRecord], proposalID: UUID?) {
        var proposal: ProposalRecord
        if let proposalID {
            guard let saved = proposals.first(where: { $0.id == proposalID }) else { return }
            proposal = saved
        } else {
            proposal = ProposalRecord(title: "Novo orçamento")
        }

        let items = calculations.compactMap(proposalItem(for:))
        guard !items.isEmpty else { return }
        proposal.items.append(contentsOf: items)
        saveProposal(proposal)
        proposalDraft = proposals.first(where: { $0.id == proposal.id })
        screen = .proposals
    }

    /// Navega até um orçamento salvo, pedindo confirmação se houver edição pendente.
    func showProposal(_ id: UUID) {
        screen = .proposals
        requestOpenProposal(id)
    }

    func startNewProposal() {
        screen = .proposals
        requestNewProposalDraft()
    }

    func showPart(_ id: UUID) {
        selectedQuoteIDs = [id]
        screen = .parts
    }

    func updateProposalItem(_ id: UUID, update: (inout ProposalItem) -> Void) {
        updateProposalDraft { proposal in
            guard let index = proposal.items.firstIndex(where: { $0.id == id }) else { return }
            update(&proposal.items[index])
            proposal.items[index].quantity = min(max(1, proposal.items[index].quantity), ProposalItem.maxQuantity)
        }
    }

    func deleteProposalItem(_ id: UUID) {
        updateProposalDraft { $0.items.removeAll { $0.id == id } }
    }

    func exportProposalPDF(_ proposal: ProposalRecord) {
        let panel = NSSavePanel()
        panel.title = "Exportar orçamento em PDF"
        panel.allowedContentTypes = [.pdf]
        panel.canCreateDirectories = true
        let baseName = proposal.title.trimmingCharacters(in: .whitespacesAndNewlines)
        panel.nameFieldStringValue = (baseName.isEmpty ? "Orcamento" : baseName) + ".pdf"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try ProposalPDFExporter.write(proposal, to: url)
            proposalPDFFeedback = "PDF salvo: \(url.lastPathComponent)"
        } catch {
            proposalPDFFeedback = error.localizedDescription
        }
    }

    func saveProposalDraft() {
        guard let proposalDraft else { return }
        saveProposal(proposalDraft)
        self.proposalDraft = proposals.first(where: { $0.id == proposalDraft.id })
    }

    private func openProposalDraft(_ id: UUID) {
        guard let proposal = proposals.first(where: { $0.id == id }) else { return }
        proposalDraft = proposal
        selectedProposalID = proposal.id
    }

    func deleteProposal(_ proposal: ProposalRecord) {
        proposals.removeAll { $0.id == proposal.id }
        proposalsStore.save(proposals)
        if selectedProposalID == proposal.id {
            selectedProposalID = proposals.first?.id
        }
        if proposalDraft?.id == proposal.id {
            proposalDraft = nil
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
