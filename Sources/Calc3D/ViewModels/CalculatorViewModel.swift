import AppKit
import Calc3DCore
import Observation

/// Telas disponíveis na barra lateral.
enum Screen: String, CaseIterable, Identifiable {
    case printJob
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .printJob: "Impressão"
        case .settings: "Parâmetros fixos"
        }
    }

    var subtitle: String {
        switch self {
        case .printJob: "Dados da peça e resultado"
        case .settings: "Máquina, energia, custos e taxas"
        }
    }

    var systemImage: String {
        switch self {
        case .printJob: "cube"
        case .settings: "slider.horizontal.3"
        }
    }
}

@MainActor
@Observable
final class CalculatorViewModel {

    /// Tela selecionada na barra lateral.
    var screen: Screen? = .printJob

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

    @ObservationIgnored private let store: ParametersStore

    init(store: ParametersStore = ParametersStore()) {
        self.store = store
        let settings = store.loadSettings()
        let job = store.loadJob()
        self.settings = settings
        self.job = job
        self.result = CostCalculator.calculate(settings: settings, job: job)
    }

    /// Começa uma nova impressão com os valores padrão, mantendo os parâmetros fixos.
    func newJob() {
        job = .defaults
        screen = .printJob
    }

    func resetSettings() {
        settings = .defaults
    }

    func copySummary() {
        let text = QuoteSummary.text(for: result, job: job)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        showFeedback("Orçamento copiado ✔")
    }

    private func recalculate() {
        result = CostCalculator.calculate(settings: settings, job: job)
    }

    private func showFeedback(_ message: String) {
        copyFeedback = message
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            self?.copyFeedback = nil
        }
    }
}
