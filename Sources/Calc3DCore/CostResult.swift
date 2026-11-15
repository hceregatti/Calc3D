import Foundation

/// Categorias que compõem o custo de uma peça.
public enum CostCategory: String, CaseIterable, Identifiable, Codable, Sendable {
    case filament
    case energy
    case depreciation
    case maintenance
    case overhead
    case failures
    case labor
    case supplies

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .filament: "Filamento"
        case .energy: "Energia"
        case .depreciation: "Depreciação"
        case .maintenance: "Manutenção"
        case .overhead: "Custos fixos"
        case .failures: "Perdas por falha"
        case .labor: "Mão de obra"
        case .supplies: "Insumos + embalagem"
        }
    }
}

/// Valor de uma categoria de custo, já dividido por peça.
public struct CostItem: Identifiable, Codable, Equatable, Sendable {
    public let category: CostCategory
    public let amount: Double
    public var id: CostCategory { category }
}

public enum PricingError: Codable, Error, Equatable, Sendable {
    /// Margem + impostos + taxas >= 100%: não existe preço que cubra os custos.
    case percentagesTooHigh(total: Double)

    public var message: String {
        switch self {
        case .percentagesTooHigh:
            "Margem + impostos + taxas somam 100% ou mais. Reduza algum deles."
        }
    }
}

/// Resultado completo de um cálculo.
public struct CostResult: Equatable, Sendable, Codable {
    /// Custos por peça, na ordem de `CostCategory.allCases`.
    public let items: [CostItem]
    public let partsPerPlate: Int
    public let printHours: Double
    public let marginPercent: Double

    /// Preço de venda sugerido por peça, ou erro de precificação.
    public let pricing: Result<Double, PricingError>

    public var unitCost: Double { items.reduce(0) { $0 + $1.amount } }
    public var plateCost: Double { unitCost * Double(partsPerPlate) }

    public var suggestedPrice: Double? { try? pricing.get() }

    /// Lucro líquido por peça (após custos, impostos e taxas).
    public var profitPerPart: Double? {
        suggestedPrice.map { $0 * marginPercent / 100 }
    }

    /// Lucro gerado por hora de máquina ocupada.
    public var profitPerMachineHour: Double? {
        guard let profit = profitPerPart, printHours > 0 else { return nil }
        return profit * Double(partsPerPlate) / printHours
    }

    public func amount(for category: CostCategory) -> Double {
        items.first { $0.category == category }?.amount ?? 0
    }

    /// Participação (0...1) de uma categoria no custo da peça.
    public func share(of category: CostCategory) -> Double {
        unitCost > 0 ? amount(for: category) / unitCost : 0
    }
}


extension CostResult {
    private enum CodingKeys: String, CodingKey {
        case items, partsPerPlate, printHours, marginPercent, suggestedPrice, pricingError
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = try container.decode([CostItem].self, forKey: .items)
        partsPerPlate = try container.decode(Int.self, forKey: .partsPerPlate)
        printHours = try container.decode(Double.self, forKey: .printHours)
        marginPercent = try container.decode(Double.self, forKey: .marginPercent)
        if let price = try container.decodeIfPresent(Double.self, forKey: .suggestedPrice) {
            pricing = .success(price)
        } else if let error = try container.decodeIfPresent(PricingError.self, forKey: .pricingError) {
            pricing = .failure(error)
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.suggestedPrice,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Quote price result is missing")
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(items, forKey: .items)
        try container.encode(partsPerPlate, forKey: .partsPerPlate)
        try container.encode(printHours, forKey: .printHours)
        try container.encode(marginPercent, forKey: .marginPercent)
        switch pricing {
        case .success(let price):
            try container.encode(price, forKey: .suggestedPrice)
        case .failure(let error):
            try container.encode(error, forKey: .pricingError)
        }
    }
}
