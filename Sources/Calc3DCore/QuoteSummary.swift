import Foundation

/// Gera o texto de orçamento para copiar e colar (WhatsApp, e-mail etc.).
public enum QuoteSummary {
    public static func text(for result: CostResult, job: PrintJob) -> String {
        let hours = result.printHours.formatted(
            .number.precision(.fractionLength(0...2)).locale(Currency.locale))
        let weight = Weight.format(grams: job.partWeight)
        let name = job.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = name.isEmpty ? "Orçamento impressão 3D" : "Orçamento: \(name)"

        var lines = ["\(title): \(result.partsPerPlate) peça(s), \(hours) h, \(weight)"]
        lines += result.items.map { "• \($0.category.title): \(Currency.format($0.amount))" }
        lines.append("Custo por peça: \(Currency.format(result.unitCost))")
        switch result.pricing {
        case .success(let price):
            lines.append("Preço sugerido: \(Currency.format(price)) (margem \(Int(result.marginPercent))%)")
        case .failure(let error):
            lines.append("Preço sugerido: indisponível (\(error.message))")
        }
        return lines.joined(separator: "\n")
    }
}
