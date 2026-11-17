import AppKit
import Calc3DCore

extension CalculatorViewModel {
    func filament(withID id: UUID?) -> Filament? {
        id.flatMap { id in filaments.first { $0.id == id } }
    }

    /// Adiciona um filamento novo e o seleciona para edição.
    func addFilament(material: FilamentMaterial = .pla) {
        let filament = Filament(material: material)
        filaments.insert(filament, at: 0)
        selectedFilamentID = filament.id
        screen = .filaments
    }

    func duplicateFilament(_ filament: Filament) {
        var copy = filament
        copy.id = UUID()
        copy.createdAt = .now
        copy.remainingWeight = copy.netWeight
        filaments.insert(copy, at: 0)
        selectedFilamentID = copy.id
    }

    func deleteFilament(_ id: UUID) {
        filaments.removeAll { $0.id == id }
        if selectedFilamentID == id { selectedFilamentID = nil }
    }

    func openFilamentSearch(_ filament: Filament) {
        if let url = filament.searchURL { NSWorkspace.shared.open(url) }
    }

    func openFilamentPurchase(_ filament: Filament) {
        if let url = filament.purchaseLink { NSWorkspace.shared.open(url) }
    }

    /// Usa o filamento da biblioteca no cálculo da peça (nil volta ao padrão dos parâmetros fixos).
    func useFilament(_ filament: Filament?, in calculator: PartCalculator) {
        calculator.job.filamentID = filament?.id
        calculator.job.filamentName = filament?.displayName
        calculator.job.filamentPricePerGram = filament?.pricePerGram
    }

    /// Mantém a peça em cálculo alinhada ao preço do filamento quando ele é editado.
    func syncJobFilament() {
        for calc in [calculator, partDraft].compactMap({ $0 }) {
            guard let id = calc.job.filamentID, let f = filament(withID: id) else { continue }
            if calc.job.filamentName != f.displayName { calc.job.filamentName = f.displayName }
            if calc.job.filamentPricePerGram != f.pricePerGram { calc.job.filamentPricePerGram = f.pricePerGram }
        }
    }
}
