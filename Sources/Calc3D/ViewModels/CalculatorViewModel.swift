import AppKit
import Calc3DCore
import Observation

@MainActor
@Observable
final class CalculatorViewModel {

    var parameters: PrintParameters {
        didSet {
            guard parameters != oldValue else { return }
            result = CostCalculator.calculate(parameters)
            store.save(parameters)
        }
    }

    private(set) var result: CostResult
    private(set) var copyFeedback: String?

    @ObservationIgnored private let store: ParametersStore

    init(store: ParametersStore = ParametersStore()) {
        self.store = store
        let loaded = store.load()
        self.parameters = loaded
        self.result = CostCalculator.calculate(loaded)
    }

    func reset() {
        parameters = .defaults
    }

    func copySummary() {
        let text = QuoteSummary.text(for: result, parameters: parameters)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        showFeedback("Orçamento copiado ✔")
    }

    private func showFeedback(_ message: String) {
        copyFeedback = message
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            self?.copyFeedback = nil
        }
    }
}
