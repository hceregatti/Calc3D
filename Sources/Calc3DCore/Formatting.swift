import Foundation

// MARK: - Preferências de exibição

/// Moedas disponíveis para exibir valores. Não há conversão: muda só o símbolo/código.
public enum CurrencyOption: String, CaseIterable, Codable, Sendable, Identifiable {
    case brl = "BRL"
    case usd = "USD"
    case eur = "EUR"
    case gbp = "GBP"

    public var id: String { rawValue }

    public var symbol: String {
        switch self {
        case .brl: "R$"
        case .usd: "US$"
        case .eur: "€"
        case .gbp: "£"
        }
    }

    public var title: String {
        switch self {
        case .brl: "Real (R$)"
        case .usd: "Dólar americano (US$)"
        case .eur: "Euro (€)"
        case .gbp: "Libra esterlina (£)"
        }
    }
}

/// Unidade usada para digitar e exibir pesos. Internamente tudo é guardado em gramas.
public enum WeightUnit: String, CaseIterable, Codable, Sendable, Identifiable {
    case gram = "g"
    case kilogram = "kg"
    case ounce = "oz"
    case pound = "lb"

    public var id: String { rawValue }
    public var symbol: String { rawValue }

    public var title: String {
        switch self {
        case .gram: "Grama (g)"
        case .kilogram: "Quilograma (kg)"
        case .ounce: "Onça (oz)"
        case .pound: "Libra (lb)"
        }
    }

    /// Quantos gramas há em 1 unidade.
    public var grams: Double {
        switch self {
        case .gram: 1
        case .kilogram: 1000
        case .ounce: 28.349523125
        case .pound: 453.59237
        }
    }

    /// Casas decimais aceitas na digitação.
    public var fractionDigits: Int {
        switch self {
        case .gram, .ounce: 2
        case .kilogram, .pound: 3
        }
    }

    /// Unidade "grande" usada no preço do filamento (R$/kg ou R$/lb).
    public var bulkUnit: WeightUnit {
        switch self {
        case .gram, .kilogram: .kilogram
        case .ounce, .pound: .pound
        }
    }

    public func fromGrams(_ grams: Double) -> Double { grams / self.grams }
    public func toGrams(_ value: Double) -> Double { value * grams }
}

/// Preferências globais de exibição, sincronizadas com os parâmetros fixos.
public enum DisplayPreferences {
    nonisolated(unsafe) public static var currency: CurrencyOption = .brl
    nonisolated(unsafe) public static var weightUnit: WeightUnit = .gram

    public static func apply(_ settings: ShopSettings) {
        currency = settings.currency
        weightUnit = settings.weightUnit
    }
}

// MARK: - Moeda

public enum Currency {
    /// Números sempre no padrão brasileiro: 7.000,00.
    public static let locale = Locale(identifier: "pt_BR")

    public static var symbol: String { DisplayPreferences.currency.symbol }

    /// Formata na moeda escolhida nos parâmetros fixos (ex.: R$ 7.000,00).
    public static func format(_ value: Double) -> String {
        format(value, currency: DisplayPreferences.currency)
    }

    public static func format(_ value: Double, currency: CurrencyOption) -> String {
        (value.isFinite ? value : 0)
            .formatted(.currency(code: currency.rawValue).locale(locale))
    }
}

// MARK: - Peso

public enum Weight {
    /// Formata um peso em gramas na unidade escolhida (ex.: 31,17 g ou 0,031 kg).
    public static func format(grams: Double, unit: WeightUnit = DisplayPreferences.weightUnit) -> String {
        let value = unit.fromGrams(grams)
        return "\(NumberMask.format(value, maxFraction: unit.fractionDigits)) \(unit.symbol)"
    }

    /// Preço do filamento na unidade "grande" (R$/kg ou R$/lb).
    public static func pricePerBulkUnit(perGram: Double, unit: WeightUnit = DisplayPreferences.weightUnit) -> String {
        Currency.format(perGram * unit.bulkUnit.grams) + "/" + unit.bulkUnit.symbol
    }
}

// MARK: - Máscara numérica

/// Máscara de números no padrão brasileiro: milhar com ponto e decimal com vírgula.
public enum NumberMask {
    /// Limite de dígitos na parte inteira (evita valores absurdos).
    public static let maxIntegerDigits = 12

    public static func format(_ value: Double, minFraction: Int = 0, maxFraction: Int = 2) -> String {
        guard value.isFinite else { return "" }
        return value.formatted(
            .number
                .grouping(.automatic)
                .precision(.fractionLength(minFraction...max(minFraction, maxFraction)))
                .locale(Currency.locale)
        )
    }

    /// Converte texto mascarado ("7.000,5") em número. Texto vazio retorna `nil`.
    public static func parse(_ text: String) -> Double? {
        let cleaned = text
            .filter { $0.isNumber || $0 == "," || $0 == "-" }
            .replacingOccurrences(of: ",", with: ".")
        guard !cleaned.isEmpty, cleaned != "." else { return nil }
        return Double(cleaned.hasPrefix(".") ? "0" + cleaned : cleaned)
    }

    /// Aplica a máscara enquanto o usuário digita.
    ///
    /// - Vírgula é sempre o separador decimal.
    /// - Um ponto digitado (ou colado) seguido de até `maxFraction` dígitos vira vírgula,
    ///   então "31.17" vira "31,17". Pontos de milhar já exibidos são ignorados.
    public static func live(_ input: String, previous: String = "", maxFraction: Int = 2) -> String {
        let chars = Array(input)
        var decimalIndex: Int?

        if maxFraction > 0 {
            if let comma = chars.firstIndex(of: ",") {
                decimalIndex = comma
            } else {
                // Trecho inserido nesta edição: o que sobra tirando prefixo e sufixo comuns.
                let old = Array(previous)
                var prefix = 0
                while prefix < chars.count, prefix < old.count, chars[prefix] == old[prefix] { prefix += 1 }
                var suffix = 0
                while suffix < chars.count - prefix, suffix < old.count - prefix,
                      chars[chars.count - 1 - suffix] == old[old.count - 1 - suffix] { suffix += 1 }
                let inserted = prefix..<(chars.count - suffix)
                if let dot = inserted.last(where: { chars[$0] == "." }) {
                    let digitsAfter = chars[(dot + 1)...].prefix { $0 != "." }.filter(\.isNumber).count
                    if digitsAfter <= maxFraction { decimalIndex = dot }
                }
            }
        }

        let integerPart = decimalIndex.map { chars[..<$0] } ?? chars[...]
        var integerDigits = String(integerPart.filter(\.isASCIIDigit))
        while integerDigits.count > 1, integerDigits.hasPrefix("0") { integerDigits.removeFirst() }
        integerDigits = String(integerDigits.prefix(maxIntegerDigits))

        guard let decimalIndex else { return group(integerDigits) }

        let fraction = String(chars[(decimalIndex + 1)...].filter(\.isASCIIDigit).prefix(maxFraction))
        return group(integerDigits.isEmpty ? "0" : integerDigits) + "," + fraction
    }

    /// Agrupa dígitos de milhar com ponto: "7000" → "7.000".
    static func group(_ digits: String) -> String {
        var out = ""
        for (i, ch) in digits.enumerated() {
            if i > 0, (digits.count - i) % 3 == 0 { out.append(".") }
            out.append(ch)
        }
        return out
    }
}

// MARK: - Máscaras de documentos

public enum TextMask {
    /// Telefone brasileiro: (11) 3000-0000 ou (11) 90000-0000.
    /// Se o texto tiver letras ou "@" (ex.: e-mail), é mantido como está.
    public static func phone(_ input: String) -> String {
        if input.contains(where: { $0.isLetter || $0 == "@" }) { return input }
        let d = Array(input.filter(\.isASCIIDigit).prefix(11))
        guard !d.isEmpty else { return "" }
        let s = { (r: Range<Int>) in String(d[r.clamped(to: 0..<d.count)]) }
        switch d.count {
        case 1...2: return "(" + s(0..<2)
        case 3...6: return "(\(s(0..<2))) \(s(2..<6))"
        case 7...10: return "(\(s(0..<2))) \(s(2..<6))-\(s(6..<10))"
        default: return "(\(s(0..<2))) \(s(2..<7))-\(s(7..<11))"
        }
    }

    /// CPF (000.000.000-00) ou CNPJ (00.000.000/0000-00), inclusive o CNPJ alfanumérico.
    public static func cpfCnpj(_ input: String) -> String {
        let raw = Array(input.uppercased().filter { $0.isASCIIDigit || ($0.isASCII && $0.isLetter) }.prefix(14))
        guard !raw.isEmpty else { return "" }
        let isCPF = raw.count <= 11 && raw.allSatisfy(\.isASCIIDigit)
        let separators: [Int: String] = isCPF
            ? [3: ".", 6: ".", 9: "-"]
            : [2: ".", 5: ".", 8: "/", 12: "-"]
        var out = ""
        for (i, ch) in raw.enumerated() {
            if let sep = separators[i] { out += sep }
            out.append(ch)
        }
        return out
    }
}

private extension Character {
    var isASCIIDigit: Bool { isASCII && isNumber }
}
