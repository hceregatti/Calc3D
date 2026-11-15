import Foundation

/// Motor de cálculo de custo e preço de impressão 3D.
///
/// Fórmulas:
/// - Material     = peso × (1 + desperdício) × preço do rolo ÷ peso do rolo
/// - Energia      = W ÷ 1000 × horas × tarifa
/// - Depreciação  = (preço − revenda) ÷ vida útil × horas
/// - Manutenção   = manutenção anual ÷ horas/ano × horas
/// - Custos fixos = fixos mensais ÷ horas/mês × horas
/// - Falhas       = (material + energia + máquina + fixos) × f ÷ (1 − f)
/// - Mão de obra  = (preparação + pós) ÷ 60 × valor/h
/// - Preço        = (custo/peça + taxa fixa) ÷ (1 − margem − impostos − taxa %)
public enum CostCalculator {

    /// Taxa de falha máxima aceita, evita divisão por zero.
    public static let maxFailureRate = 0.9

    public static func calculate(_ p: PrintParameters) -> CostResult {
        let hours = p.totalPrintHours
        let parts = max(p.partsPerPlate, 1)
        let failureRate = min(max(p.failureRatePercent / 100, 0), maxFailureRate)

        let filament = nonNegative(p.partWeight) * (1 + nonNegative(p.wastePercent) / 100)
            * nonNegative(p.spoolPrice) / atLeastOne(p.spoolWeight)
        let energy = nonNegative(p.powerWatts) / 1000 * hours * nonNegative(p.energyTariff)
        let depreciation = nonNegative(p.printerPrice - p.resaleValue) / atLeastOne(p.lifetimeHours) * hours
        let maintenance = nonNegative(p.maintenancePerYear) / atLeastOne(p.hoursPerYear) * hours
        let overhead = nonNegative(p.fixedCostsPerMonth) / atLeastOne(p.hoursPerMonth) * hours

        // A falha refaz o trabalho da máquina e o material, mas o pós-processamento
        // só acontece na peça boa; por isso a mão de obra fica de fora.
        let production = filament + energy + depreciation + maintenance + overhead
        let failures = production * failureRate / (1 - failureRate)

        let labor = (nonNegative(p.setupMinutes) + nonNegative(p.postProcessingMinutes)) / 60
            * nonNegative(p.laborRate)
        let supplies = nonNegative(p.consumablesPerPlate) + nonNegative(p.packagingPerPart) * Double(parts)

        let plateAmounts: [CostCategory: Double] = [
            .filament: filament,
            .energy: energy,
            .depreciation: depreciation,
            .maintenance: maintenance,
            .overhead: overhead,
            .failures: failures,
            .labor: labor,
            .supplies: supplies,
        ]
        let items = CostCategory.allCases.map {
            CostItem(category: $0, amount: (plateAmounts[$0] ?? 0) / Double(parts))
        }
        let unitCost = items.reduce(0) { $0 + $1.amount }

        let percentages = (nonNegative(p.marginPercent) + nonNegative(p.taxPercent)
            + nonNegative(p.marketplaceFeePercent)) / 100
        let pricing: Result<Double, PricingError> = percentages >= 1
            ? .failure(.percentagesTooHigh(total: percentages * 100))
            : .success((unitCost + nonNegative(p.fixedFeePerSale)) / (1 - percentages))

        return CostResult(
            items: items,
            partsPerPlate: parts,
            printHours: hours,
            marginPercent: nonNegative(p.marginPercent),
            pricing: pricing
        )
    }

    private static func nonNegative(_ v: Double) -> Double { v.isFinite ? max(v, 0) : 0 }
    private static func atLeastOne(_ v: Double) -> Double { v.isFinite ? max(v, 1) : 1 }
}
