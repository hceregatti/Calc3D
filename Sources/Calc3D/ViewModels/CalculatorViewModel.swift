import AppKit
import Calc3DCore
import Observation
import SwiftUI

/// Telas disponíveis na barra lateral.
enum Screen: String, CaseIterable, Identifiable {
    case home
    case printJob
    case parts
    case filaments
    case catalog
    case proposals
    case settings
    case company

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Início"
        case .printJob: "Calcular peça"
        case .parts: "Peças"
        case .filaments: "Filamentos"
        case .catalog: "Catálogo"
        case .proposals: "Orçamentos"
        case .settings: "Parâmetros fixos"
        case .company: "Personalizar orçamento"
        }
    }

    var subtitle: String {
        switch self {
        case .home: "Visão geral e atalhos"
        case .printJob: "Dados da impressão e preço"
        case .parts: "Histórico de cálculos de peças"
        case .filaments: "Biblioteca de rolos e preços"
        case .catalog: "Peças compartilhadas"
        case .proposals: "Orçamentos com várias peças"
        case .settings: "Máquina, energia, custos e taxas"
        case .company: "Logo, empresa e condições"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house.fill"
        case .printJob: "cube.fill"
        case .parts: "square.stack.3d.up.fill"
        case .filaments: "cylinder.split.1x2.fill"
        case .catalog: "books.vertical.fill"
        case .proposals: "doc.text.fill"
        case .settings: "gearshape.fill"
        case .company: "paintbrush.fill"
        }
    }

    var color: Color {
        switch self {
        case .home: .blue
        case .printJob: .orange
        case .parts: .purple
        case .filaments: .indigo
        case .catalog: .cyan
        case .proposals: .green
        case .settings: .gray
        case .company: .teal
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
    /// Aba da lista de orçamentos: aguardando aprovação, vencidos ou vendas.
    var proposalFilter: ProposalStatus = .waiting
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
            DisplayPreferences.apply(settings)
            settingsFeedback = nil
            calculator.settings = settings
            partDraft?.settings = settings
        }
    }

    private(set) var lastSavedSettings: ShopSettings

    /// Dados da empresa e padrões dos orçamentos (editados com salvar explícito).
    var companyProfile: CompanyProfile {
        didSet { if companyProfile != oldValue { companyFeedback = nil } }
    }
    private(set) var lastSavedCompanyProfile: CompanyProfile
    private(set) var companyFeedback: String?
    var companyHasUnsavedChanges: Bool { companyProfile != lastSavedCompanyProfile }
    var settingsHaveUnsavedChanges: Bool { settings != lastSavedSettings }
    var proposalHasUnsavedChanges: Bool {
        guard let proposalDraft else { return false }
        guard let saved = proposals.first(where: { $0.id == proposalDraft.id }) else { return true }
        return proposalDraft != saved
    }

    /// Cálculo da tela "Calcular peça" (persistido entre aberturas do app).
    let calculator: PartCalculator

    /// Cálculo de peça aberto dentro do editor de orçamento.
    var partDraft: PartCalculator?
    var partDraftSavesToHistory = true

    var job: PrintJob {
        get { calculator.job }
        set { calculator.job = newValue }
    }

    var result: CostResult { calculator.result }

    private(set) var copyFeedback: String?
    private(set) var quoteFeedback: String?
    private(set) var proposalPDFFeedback: String?
    private(set) var quotes: [QuoteRecord]
    private(set) var proposals: [ProposalRecord]
    /// Biblioteca de filamentos (salva automaticamente a cada alteração).
    var filaments: [Filament] {
        didSet {
            guard filaments != oldValue else { return }
            filamentsStore.save(filaments)
            syncJobFilament()
            syncDefaultFilament()
        }
    }
    var selectedFilamentID: UUID?

    // Catálogo compartilhado (pasta sincronizada com outras pessoas).
    var catalogEntries: [CatalogEntry] = []
    var catalogFiles: [CatalogFile] = []
    var selectedCatalogEntryID: UUID?
    var selectedCatalogFileID: String?
    var catalogOnlyMine = false
    var catalogSearch = ""
    var catalogFolderPath: String? {
        didSet { catalogSettings.folderPath = catalogFolderPath }
    }
    var catalogUserName: String {
        didSet { catalogSettings.userName = catalogUserName }
    }
    let catalogUserID: UUID
    var catalogMessage: String?
    var isRefreshingCatalog = false
    @ObservationIgnored let catalogSettings = CatalogSettingsStore()
    var filamentPendingDeletionID: UUID?
    private(set) var settingsFeedback: String?

    @ObservationIgnored private let store: ParametersStore
    @ObservationIgnored private let quotesStore: QuotesStore
    @ObservationIgnored private let proposalsStore: ProposalsStore
    @ObservationIgnored private let filamentsStore: FilamentsStore
    @ObservationIgnored let imageStore: ImageStore

    init(
        store: ParametersStore = ParametersStore(),
        quotesStore: QuotesStore = QuotesStore(),
        proposalsStore: ProposalsStore = ProposalsStore(),
        filamentsStore: FilamentsStore = FilamentsStore(),
        imageStore: ImageStore = ImageStore()
    ) {
        self.store = store
        self.quotesStore = quotesStore
        self.proposalsStore = proposalsStore
        self.filamentsStore = filamentsStore
        let catalogPrefs = CatalogSettingsStore()
        self.catalogFolderPath = catalogPrefs.folderPath
        self.catalogUserName = catalogPrefs.userName
        self.catalogUserID = catalogPrefs.userID
        self.filaments = filamentsStore.load()
        self.imageStore = imageStore
        let company = store.loadCompany()
        self.companyProfile = company
        self.lastSavedCompanyProfile = company
        let settings = store.loadSettings()
        let job = store.loadJob()
        DisplayPreferences.apply(settings)
        self.settings = settings
        self.lastSavedSettings = settings
        self.calculator = PartCalculator(job: job, settings: settings)
        self.quotes = quotesStore.load()
        self.proposals = proposalsStore.load()
        calculator.onJobChange = { job in store.save(job) }
        pruneImages()
    }

    /// Começa uma nova impressão com os valores padrão, mantendo os parâmetros fixos.
    func newJob() {
        calculator.load(.defaults)
        screen = .printJob
    }

    /// Restaura os valores padrão, mantendo moeda e unidade de medida escolhidas.
    func resetSettings() {
        var defaults = ShopSettings.defaults
        defaults.currency = settings.currency
        defaults.weightUnit = settings.weightUnit
        settings = defaults
    }

    /// Define o filamento padrão a partir da biblioteca (nil = valores manuais, que ficam como estão).
    func setDefaultFilament(_ filament: Filament?) {
        settings.defaultFilamentID = filament?.id
        if let filament {
            settings.spoolPrice = filament.price
            settings.spoolWeight = filament.netWeight
        }
    }

    /// Mantém o filamento padrão alinhado à biblioteca quando o rolo é editado ou excluído.
    /// A alteração também vai para os parâmetros já salvos, sem salvar outras edições pendentes.
    func syncDefaultFilament() {
        guard let id = settings.defaultFilamentID else { return }
        let source = filaments.first { $0.id == id }
        func apply(_ s: inout ShopSettings) {
            guard let source else { s.defaultFilamentID = nil; return }
            s.spoolPrice = source.price
            s.spoolWeight = source.netWeight
        }
        var saved = lastSavedSettings
        apply(&saved)
        if saved != lastSavedSettings {
            store.save(saved)
            lastSavedSettings = saved
        }
        var current = settings
        apply(&current)
        settings = current
    }

    func saveSettings() {
        guard settingsHaveUnsavedChanges else { return }
        store.save(settings)
        lastSavedSettings = settings
        settingsFeedback = "Parâmetros salvos ✔"
    }

    func saveCompanyProfile() {
        guard companyHasUnsavedChanges else { return }
        store.save(companyProfile)
        lastSavedCompanyProfile = companyProfile
        companyFeedback = "Dados salvos ✔"
        pruneImages()
    }

    func resetCompanyDefaults() {
        let defaults = CompanyProfile.defaults
        companyProfile.defaultValidityDays = defaults.defaultValidityDays
        companyProfile.defaultPaymentTerms = defaults.defaultPaymentTerms
        companyProfile.defaultDeliveryTime = defaults.defaultDeliveryTime
        companyProfile.defaultNotes = defaults.defaultNotes
        companyProfile.footerText = defaults.footerText
    }

    func chooseCompanyLogo() {
        guard let id = imageStore.chooseImage(kind: .logo, title: "Escolher logo da empresa") else { return }
        companyProfile.logoImageID = id
    }

    func setCompanyLogo(from url: URL) -> Bool {
        guard let id = imageStore.importImage(from: url, kind: .logo) else { return false }
        companyProfile.logoImageID = id
        return true
    }

    func chooseProductPhoto(for itemID: UUID) {
        guard let id = imageStore.chooseImage(kind: .product, title: "Escolher foto do produto") else { return }
        updateProposalItem(itemID) { $0.imageID = id }
    }

    func setProductPhoto(for itemID: UUID, from url: URL) -> Bool {
        guard let id = imageStore.importImage(from: url, kind: .product) else { return false }
        updateProposalItem(itemID) { $0.imageID = id }
        return true
    }

    /// Gera um PDF de exemplo com os dados atuais (mesmo não salvos) e abre no Preview.
    func previewSampleProposalPDF() {
        var sample = ProposalRecord(defaultsFrom: companyProfile, title: "Orçamento de exemplo")
        sample.number = companyProfile.nextProposalNumber
        sample.customerName = "Cliente Exemplo"
        sample.customerContact = "(11) 90000-0000 · cliente@exemplo.com"
        sample.items = [
            ProposalItem(name: "Suporte articulado", details: "PLA preto, acabamento fosco", quantity: 2, unitPrice: 45.9),
            ProposalItem(name: "Miniatura personalizada", details: "Resina, pintada à mão", quantity: 1, unitPrice: 120),
        ]
        sample.shipping = 25
        let url = FileManager.default.temporaryDirectory.appending(path: "Calc3D-exemplo.pdf")
        do {
            try ProposalPDFExporter.write(sample, profile: companyProfile, images: imageStore, to: url)
            NSWorkspace.shared.open(url)
            companyFeedback = nil
        } catch {
            companyFeedback = error.localizedDescription
        }
    }

    /// Mantém só as imagens referenciadas por orçamentos salvos, o rascunho e o perfil.
    private func pruneImages() {
        var ids = Set<UUID>()
        for proposal in proposals + [proposalDraft].compactMap({ $0 }) {
            ids.formUnion(proposal.items.compactMap(\.imageID))
        }
        if let logo = companyProfile.logoImageID { ids.insert(logo) }
        if let logo = lastSavedCompanyProfile.logoImageID { ids.insert(logo) }
        imageStore.prune(keeping: ids)
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
        if proposal.number == nil {
            proposal.number = takeNextProposalNumber()
        }
        if let index = proposals.firstIndex(where: { $0.id == proposal.id }) {
            proposals[index] = proposal
        } else {
            proposals.insert(proposal, at: 0)
        }
        proposals.sort { $0.updatedAt > $1.updatedAt }
        proposalsStore.save(proposals)
        selectedProposalID = proposal.id
        proposalFilter = proposal.status()
    }

    /// Reserva o próximo número sequencial sem descartar edições pendentes do perfil.
    private func takeNextProposalNumber() -> Int {
        let number = max(lastSavedCompanyProfile.nextProposalNumber, 1)
        let wasInSync = companyProfile.nextProposalNumber == lastSavedCompanyProfile.nextProposalNumber
        lastSavedCompanyProfile.nextProposalNumber = number + 1
        store.save(lastSavedCompanyProfile)
        if wasInSync {
            companyProfile.nextProposalNumber = number + 1
        }
        return number
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
        let proposal = ProposalRecord(defaultsFrom: lastSavedCompanyProfile)
        proposalDraft = proposal
        selectedProposalID = proposal.id
    }

    func updateProposalDraft(_ update: (inout ProposalRecord) -> Void) {
        guard var proposal = proposalDraft else { return }
        update(&proposal)
        proposalDraft = proposal
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
            sourceQuoteID: quotes.contains { $0.id == quote.id } ? quote.id : nil,
            filamentID: quote.job.filamentID,
            filamentName: quote.job.filamentName,
            gramsPerUnit: FilamentUsage.gramsPerUnit(job: quote.job)
        )
    }

    private func appendCalculationsToProposal(_ calculations: [QuoteRecord], proposalID: UUID?) {
        var proposal: ProposalRecord
        if let proposalID {
            guard let saved = proposals.first(where: { $0.id == proposalID }) else { return }
            proposal = saved
        } else {
            proposal = ProposalRecord(defaultsFrom: lastSavedCompanyProfile)
        }

        let items = calculations.compactMap(proposalItem(for:))
        guard !items.isEmpty else { return }
        proposal.items.append(contentsOf: items)
        saveProposal(proposal)
        proposalDraft = proposals.first(where: { $0.id == proposal.id })
        screen = .proposals
    }

    /// Abre o cálculo completo de uma peça para incluir no orçamento em edição.
    func startPartDraft() {
        guard proposalDraft != nil else { return }
        partDraftSavesToHistory = true
        partDraft = PartCalculator(settings: settings)
    }

    func cancelPartDraft() {
        partDraft = nil
    }

    /// Adiciona a peça calculada ao orçamento e, se escolhido, ao histórico de peças.
    func commitPartDraft() {
        guard let partDraft, partDraft.canPrice else { return }
        let quote = partDraft.snapshot
        if partDraftSavesToHistory {
            quotes.insert(quote, at: 0)
            quotesStore.save(quotes)
        }
        addQuotesToDraft([quote])
        self.partDraft = nil
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
        let prefix = proposal.formattedNumber.map { "Orcamento \($0) - " } ?? ""
        panel.nameFieldStringValue = prefix + (baseName.isEmpty ? "Orcamento" : baseName) + ".pdf"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try ProposalPDFExporter.write(proposal, profile: lastSavedCompanyProfile, images: imageStore, to: url)
            proposalPDFFeedback = "PDF salvo: \(url.lastPathComponent)"
        } catch {
            proposalPDFFeedback = error.localizedDescription
        }
    }

    func saveProposalDraft() {
        guard let proposalDraft else { return }
        saveProposal(proposalDraft)
        self.proposalDraft = proposals.first(where: { $0.id == proposalDraft.id })
        pruneImages()
    }

    private func openProposalDraft(_ id: UUID) {
        guard let proposal = proposals.first(where: { $0.id == id }) else { return }
        proposalDraft = proposal
        selectedProposalID = proposal.id
        proposalFilter = proposal.status()
    }

    func deleteProposal(_ proposal: ProposalRecord) {
        proposals.removeAll { $0.id == proposal.id }
        proposalsStore.save(proposals)
        if selectedProposalID == proposal.id {
            selectedProposalID = proposals.first?.id
        }
        if proposalDraft?.id == proposal.id {
            proposalDraft = nil
            partDraft = nil
        }
        pruneImages()
    }

    /// Reutiliza os dados da peça, sem substituir os parâmetros fixos atuais.
    /// Guarda uma cópia de peça (ex.: vinda do catálogo) no histórico.
    func addQuoteToHistory(_ quote: QuoteRecord) {
        quotes.insert(quote, at: 0)
        quotesStore.save(quotes)
        selectedQuoteIDs = [quote.id]
    }

    func useQuoteAsBase(_ quote: QuoteRecord) {
        calculator.load(quote.job)
        screen = .printJob
    }

    func copySummary() {
        let text = QuoteSummary.text(for: result, job: job)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        showCopyFeedback("Orçamento copiado ✔")
    }

    private func showCopyFeedback(_ message: String) {
        copyFeedback = message
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            self?.copyFeedback = nil
        }
    }

    func showQuoteFeedback(_ message: String) {
        quoteFeedback = message
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            self?.quoteFeedback = nil
        }
    }
}
