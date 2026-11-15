import Foundation

public enum Currency {
    public static let locale = Locale(identifier: "pt_BR")

    public static func brl(_ value: Double) -> String {
        value.formatted(.currency(code: "BRL").locale(locale))
    }
}

/// Gera o texto de orçamento para copiar e colar (WhatsApp, e-mail etc.).
public enum QuoteSummary {
    public static func text(for result: CostResult, job: PrintJob) -> String {
        let hours = result.printHours.formatted(
            .number.precision(.fractionLength(0...2)).locale(Currency.locale))
        let weight = job.partWeight.formatted(.number.locale(Currency.locale))
        let name = job.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = name.isEmpty ? "Orçamento impressão 3D" : "Orçamento: \(name)"

        var lines = ["\(title): \(result.partsPerPlate) peça(s), \(hours) h, \(weight) g"]
        lines += result.items.map { "• \($0.category.title): \(Currency.brl($0.amount))" }
        lines.append("Custo por peça: \(Currency.brl(result.unitCost))")
        switch result.pricing {
        case .success(let price):
            lines.append("Preço sugerido: \(Currency.brl(price)) (margem \(Int(result.marginPercent))%)")
        case .failure(let error):
            lines.append("Preço sugerido: indisponível (\(error.message))")
        }
        return lines.joined(separator: "\n")
    }
}
