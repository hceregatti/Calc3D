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

    public init() {}

    public static let defaults = ShopSettings()

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
