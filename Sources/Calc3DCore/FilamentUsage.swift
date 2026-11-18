import Foundation

/// Uma baixa registrada no estoque de um rolo, guardada no orçamento que a gerou.
public struct StockDeduction: Codable, Equatable, Sendable {
    public var filamentID: UUID
    public var filamentName: String
    /// Quanto o orçamento precisava.
    public var requestedGrams: Double
    /// Quanto realmente saiu do rolo (limitado ao que restava); é o que o estorno devolve.
    public var grams: Double
    public var date: Date

    public init(filamentID: UUID, filamentName: String, requestedGrams: Double, grams: Double, date: Date = .now) {
        self.filamentID = filamentID
        self.filamentName = filamentName
        self.requestedGrams = requestedGrams
        self.grams = grams
        self.date = date
    }
}

/// Consumo de filamento: do cálculo da peça à baixa no estoque. Funções puras.
public enum FilamentUsage {

    /// Gramas de filamento por unidade vendida: peso da mesa com desperdício, dividido pelas peças da mesa.
    /// Nil quando a peça não usa um filamento da biblioteca.
    public static func gramsPerUnit(job: PrintJob) -> Double? {
        guard job.filamentID != nil else { return nil }
        let parts = Double(max(job.partsPerPlate, 1))
        return Sanitize.nonNegative(job.partWeight) * (1 + Sanitize.nonNegative(job.wastePercent) / 100) / parts
    }

    public struct Line: Equatable, Sendable {
        public var filamentID: UUID?
        public var filamentName: String
        public var gramsPerUnit: Double?
        public var quantity: Int

        public init(filamentID: UUID?, filamentName: String, gramsPerUnit: Double?, quantity: Int) {
            self.filamentID = filamentID
            self.filamentName = filamentName
            self.gramsPerUnit = gramsPerUnit
            self.quantity = quantity
        }
    }

    public struct Requirement: Equatable, Sendable {
        public var filamentID: UUID
        public var filamentName: String
        public var grams: Double
    }

    /// Soma o consumo por rolo; itens sem filamento são ignorados.
    public static func requirements(_ lines: [Line]) -> [Requirement] {
        var byID: [UUID: Requirement] = [:]
        for line in lines {
            guard let id = line.filamentID, let per = line.gramsPerUnit else { continue }
            let grams = Sanitize.nonNegative(per) * Double(max(line.quantity, 0))
            var entry = byID[id] ?? Requirement(filamentID: id, filamentName: line.filamentName, grams: 0)
            entry.grams += grams
            byID[id] = entry
        }
        return byID.values.sorted { $0.filamentName.localizedCompare($1.filamentName) == .orderedAscending }
    }

    /// Quanto falta (g) para atender o consumo; 0 se o rolo dá conta.
    public static func shortage(required: Double, available: Double) -> Double {
        max(required - Sanitize.nonNegative(available), 0)
    }

    /// Desconta o consumo dos rolos (nunca abaixo de zero) e devolve o que foi baixado de fato.
    /// Rolos que não existem mais na biblioteca são ignorados.
    @discardableResult
    public static func deduct(_ requirements: [Requirement], from filaments: inout [Filament], date: Date = .now) -> [StockDeduction] {
        var result: [StockDeduction] = []
        for need in requirements {
            guard let index = filaments.firstIndex(where: { $0.id == need.filamentID }) else { continue }
            let available = Sanitize.nonNegative(filaments[index].remainingWeight)
            let taken = min(need.grams, available)
            filaments[index].remainingWeight = available - taken
            result.append(StockDeduction(
                filamentID: need.filamentID, filamentName: filaments[index].displayName,
                requestedGrams: need.grams, grams: taken, date: date
            ))
        }
        return result
    }

    /// Devolve aos rolos exatamente o que as baixas retiraram.
    public static func revert(_ deductions: [StockDeduction], in filaments: inout [Filament]) {
        for d in deductions {
            guard let index = filaments.firstIndex(where: { $0.id == d.filamentID }) else { continue }
            let f = filaments[index]
            filaments[index].remainingWeight = min(Sanitize.nonNegative(f.remainingWeight) + d.grams, max(f.netWeight, f.remainingWeight))
        }
    }

    /// True quando o consumo atual difere do que foi baixado (orçamento editado depois da baixa).
    public static func hasChanged(since deductions: [StockDeduction], requirements: [Requirement]) -> Bool {
        let before = Dictionary(deductions.map { ($0.filamentID, $0.requestedGrams) }, uniquingKeysWith: +)
        let now = Dictionary(requirements.map { ($0.filamentID, $0.grams) }, uniquingKeysWith: +)
        guard Set(before.keys) == Set(now.keys) else { return true }
        return now.contains { abs($0.value - (before[$0.key] ?? 0)) > 0.0001 }
    }
}

extension Filament {
    /// Rolo com pouco material (15% ou menos).
    public var isRunningLow: Bool { remainingFraction <= 0.15 }
}
