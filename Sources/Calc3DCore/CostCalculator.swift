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

    public static func calculate(settings s: ShopSettings, job: PrintJob) -> CostResult {
        let hours = job.totalPrintHours
        let parts = max(job.partsPerPlate, 1)
        let f = s.failureRate

        let filament = Sanitize.nonNegative(job.partWeight)
            * (1 + Sanitize.nonNegative(job.wastePercent) / 100) * s.filamentPricePerGram
        let energy = s.energyCostPerHour * hours
        let depreciation = s.depreciationPerHour * hours
        let maintenance = s.maintenancePerHour * hours
        let overhead = s.overheadPerHour * hours

        // A falha refaz o trabalho da máquina e o material, mas o pós-processamento
        // só acontece na peça boa; por isso a mão de obra fica de fora.
        let production = filament + energy + depreciation + maintenance + overhead
        let failures = production * f / (1 - f)

        let labor = (Sanitize.nonNegative(job.setupMinutes) + Sanitize.nonNegative(job.postProcessingMinutes))
            / 60 * Sanitize.nonNegative(s.laborRate)
        let supplies = Sanitize.nonNegative(job.consumablesPerPlate)
            + Sanitize.nonNegative(s.packagingPerPart) * Double(parts)

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

        let margin = Sanitize.nonNegative(job.marginPercent)
        let percentages = (margin + Sanitize.nonNegative(s.taxPercent)
            + Sanitize.nonNegative(s.marketplaceFeePercent)) / 100
        let pricing: Result<Double, PricingError> = percentages >= 1
            ? .failure(.percentagesTooHigh(total: percentages * 100))
            : .success((unitCost + Sanitize.nonNegative(s.fixedFeePerSale)) / (1 - percentages))

        return CostResult(
            items: items,
            partsPerPlate: parts,
            printHours: hours,
            marginPercent: margin,
            pricing: pricing
        )
    }
}
