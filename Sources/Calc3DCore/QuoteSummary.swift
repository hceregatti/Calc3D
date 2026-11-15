import Foundation

public enum Currency {
    public static let locale = Locale(identifier: "pt_BR")

    public static func brl(_ value: Double) -> String {
        value.formatted(.currency(code: "BRL").locale(locale))
    }
}

/// Gera o texto de orçamento para copiar e colar (WhatsApp, e-mail etc.).
public enum QuoteSummary {
    public static func text(for result: CostResult, parameters: PrintParameters) -> String {
        let hours = result.printHours.formatted(
            .number.precision(.fractionLength(0...2)).locale(Currency.locale))
        var lines = [
            "Orçamento impressão 3D: \(result.partsPerPlate) peça(s), \(hours) h, "
                + "\(parameters.partWeight.formatted(.number.locale(Currency.locale))) g"
        ]
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
