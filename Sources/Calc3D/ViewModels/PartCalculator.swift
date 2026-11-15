import AppKit
import Calc3DCore
import Observation
import UniformTypeIdentifiers

/// Estado e regras do cálculo de uma peça: dados da impressão, resultado e importação de arquivo.
/// Usado na tela "Calcular peça" e no cálculo de peças feito dentro de um orçamento.
@MainActor
@Observable
final class PartCalculator {
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
            onJobChange?(job)
            recalculate()
        }
    }

    var settings: ShopSettings {
        didSet {
            guard settings != oldValue else { return }
            recalculate()
        }
    }

    private(set) var result: CostResult
    private(set) var importFeedback: String?
    private(set) var isImportingModel = false
    private(set) var importedWeightNeedsInput = false
    private(set) var importedTimeNeedsInput = false

    @ObservationIgnored var onJobChange: ((PrintJob) -> Void)?

    var canPrice: Bool {
        result.suggestedPrice.map { $0.isFinite && $0 >= 0 } ?? false
    }

    var snapshot: QuoteRecord {
        QuoteRecord(job: job, settings: settings, result: result)
    }

    init(job: PrintJob = .defaults, settings: ShopSettings) {
        self.job = job
        self.settings = settings
        self.result = CostCalculator.calculate(settings: settings, job: job)
    }

    /// Substitui os dados da peça e limpa o estado de importação.
    func load(_ job: PrintJob) {
        clearImportState()
        self.job = job
    }

    func clearImportState() {
        importFeedback = nil
        importedWeightNeedsInput = false
        importedTimeNeedsInput = false
    }

    func importModel() {
        let panel = NSOpenPanel()
        panel.title = "Importar modelo 3D"
        panel.allowedContentTypes = ["stl", "3mf"].compactMap { UTType(filenameExtension: $0) }
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
        importedJob.partWeight = data.weightGrams ?? 0
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

    private func recalculate() {
        result = CostCalculator.calculate(settings: settings, job: job)
    }
}
