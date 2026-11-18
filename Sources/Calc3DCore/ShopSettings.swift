import Foundation

/// Parâmetros que mudam pouco: filamento padrão, energia, máquina, mão de obra,
/// custos fixos, falhas e encargos de venda. Configurados uma vez e reutilizados
/// em todas as impressões.
public struct ShopSettings: Codable, Equatable, Sendable {

    // MARK: Filamento padrão
    /// Preço do rolo de filamento (R$).
    public var spoolPrice: Double = 120
    /// Peso líquido do rolo (g).
    public var spoolWeight: Double = 1000
    /// Filamento da biblioteca usado como padrão; nil = preço e peso digitados à mão.
    public var defaultFilamentID: UUID?

    // MARK: Energia
    /// Consumo médio real da impressora (W), não a potência da fonte.
    public var powerWatts: Double = 150
    /// Tarifa de energia com impostos e bandeira (R$/kWh).
    public var energyTariff: Double = 1.05

    // MARK: Máquina
    public var printerPrice: Double = 3500
    public var resaleValue: Double = 700
    /// Vida útil esperada da impressora (h).
    public var lifetimeHours: Double = 5000
    /// Gasto anual com bicos, mesa, correias, ventoinhas (R$).
    public var maintenancePerYear: Double = 400
    public var hoursPerYear: Double = 1500

    // MARK: Mão de obra
    /// Valor da hora de trabalho (R$/h).
    public var laborRate: Double = 30
    /// Embalagem por peça (R$).
    public var packagingPerPart: Double = 3

    // MARK: Custos fixos e falhas
    /// Aluguel, software, internet, contador, DAS (R$/mês).
    public var fixedCostsPerMonth: Double = 150
    public var hoursPerMonth: Double = 125
    /// Percentual de impressões perdidas (%).
    public var failureRatePercent: Double = 10

    // MARK: Encargos de venda
    public var taxPercent: Double = 6
    /// Comissão de marketplace e/ou taxa de cartão (%).
    public var marketplaceFeePercent: Double = 14
    /// Tarifa fixa cobrada por venda (R$).
    public var fixedFeePerSale: Double = 4

    // MARK: Exibição
    /// Moeda usada para exibir os valores (sem conversão).
    public var currency: CurrencyOption = .brl
    /// Unidade usada para digitar e exibir pesos (os valores ficam em gramas).
    public var weightUnit: WeightUnit = .gram

    public init() {}

    public static let defaults = ShopSettings()

    /// Decodifica campo a campo para que novas propriedades não invalidem dados salvos.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            (try? c.decodeIfPresent(T.self, forKey: key)) ?? fallback
        }
        let d = Self.defaults
        spoolPrice = value(.spoolPrice, d.spoolPrice)
        spoolWeight = value(.spoolWeight, d.spoolWeight)
        defaultFilamentID = try? c.decodeIfPresent(UUID.self, forKey: .defaultFilamentID)
        powerWatts = value(.powerWatts, d.powerWatts)
        energyTariff = value(.energyTariff, d.energyTariff)
        printerPrice = value(.printerPrice, d.printerPrice)
        resaleValue = value(.resaleValue, d.resaleValue)
        lifetimeHours = value(.lifetimeHours, d.lifetimeHours)
        maintenancePerYear = value(.maintenancePerYear, d.maintenancePerYear)
        hoursPerYear = value(.hoursPerYear, d.hoursPerYear)
        laborRate = value(.laborRate, d.laborRate)
        packagingPerPart = value(.packagingPerPart, d.packagingPerPart)
        fixedCostsPerMonth = value(.fixedCostsPerMonth, d.fixedCostsPerMonth)
        hoursPerMonth = value(.hoursPerMonth, d.hoursPerMonth)
        failureRatePercent = value(.failureRatePercent, d.failureRatePercent)
        taxPercent = value(.taxPercent, d.taxPercent)
        marketplaceFeePercent = value(.marketplaceFeePercent, d.marketplaceFeePercent)
        fixedFeePerSale = value(.fixedFeePerSale, d.fixedFeePerSale)
        currency = value(.currency, d.currency)
        weightUnit = value(.weightUnit, d.weightUnit)
    }

    // MARK: Custos derivados

    /// Preço do filamento por grama (R$/g).
    public var filamentPricePerGram: Double {
        Sanitize.nonNegative(spoolPrice) / Sanitize.atLeastOne(spoolWeight)
    }

    /// Energia por hora de impressão (R$/h).
    public var energyCostPerHour: Double {
        Sanitize.nonNegative(powerWatts) / 1000 * Sanitize.nonNegative(energyTariff)
    }

    /// Depreciação por hora de impressão (R$/h).
    public var depreciationPerHour: Double {
        Sanitize.nonNegative(printerPrice - resaleValue) / Sanitize.atLeastOne(lifetimeHours)
    }

    /// Manutenção por hora de impressão (R$/h).
    public var maintenancePerHour: Double {
        Sanitize.nonNegative(maintenancePerYear) / Sanitize.atLeastOne(hoursPerYear)
    }

    /// Custos fixos rateados por hora de impressão (R$/h).
    public var overheadPerHour: Double {
        Sanitize.nonNegative(fixedCostsPerMonth) / Sanitize.atLeastOne(hoursPerMonth)
    }

    /// Custo total de uma hora de máquina, antes das falhas (R$/h).
    public var machineCostPerHour: Double {
        energyCostPerHour + depreciationPerHour + maintenancePerHour + overheadPerHour
    }

    /// Taxa de falha normalizada para 0...`maxFailureRate`.
    public var failureRate: Double {
        min(Sanitize.nonNegative(failureRatePercent) / 100, CostCalculator.maxFailureRate)
    }
}
