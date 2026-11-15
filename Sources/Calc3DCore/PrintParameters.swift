import Foundation

/// Todos os parâmetros de entrada de um orçamento de impressão 3D.
///
/// Peso e tempo referem-se à mesa inteira; o custo é dividido por `partsPerPlate`.
public struct PrintParameters: Codable, Equatable, Sendable {

    // MARK: Filamento
    /// Preço do rolo de filamento (R$).
    public var spoolPrice: Double = 120
    /// Peso líquido do rolo (g).
    public var spoolWeight: Double = 1000
    /// Peso de filamento informado pelo fatiador para a mesa (g).
    public var partWeight: Double = 85
    /// Desperdício com purga, skirt/brim e troca de cor (%).
    public var wastePercent: Double = 5

    // MARK: Tempo e quantidade
    public var printHours: Double = 6
    public var printMinutes: Double = 30
    /// Quantidade de peças impressas na mesma mesa.
    public var partsPerPlate: Int = 1

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

    // MARK: Mão de obra e insumos
    /// Valor da hora de trabalho (R$/h).
    public var laborRate: Double = 30
    /// Fatiar, preparar mesa, retirar peça (min).
    public var setupMinutes: Double = 15
    /// Remover suportes, lixar, pintar (min).
    public var postProcessingMinutes: Double = 20
    /// Cola, lixa, tinta, primer etc. por mesa (R$).
    public var consumablesPerPlate: Double = 2
    /// Embalagem por peça (R$).
    public var packagingPerPart: Double = 3

    // MARK: Custos fixos e falhas
    /// Aluguel, software, internet, contador, DAS (R$/mês).
    public var fixedCostsPerMonth: Double = 150
    public var hoursPerMonth: Double = 125
    /// Percentual de impressões perdidas (%).
    public var failureRatePercent: Double = 10

    // MARK: Preço de venda
    /// Margem de lucro sobre o preço de venda (%), não markup.
    public var marginPercent: Double = 40
    public var taxPercent: Double = 6
    /// Comissão de marketplace e/ou taxa de cartão (%).
    public var marketplaceFeePercent: Double = 14
    /// Tarifa fixa cobrada por venda (R$).
    public var fixedFeePerSale: Double = 4

    public init() {}

    public static let defaults = PrintParameters()

    /// Tempo total de impressão em horas.
    public var totalPrintHours: Double {
        max(printHours, 0) + max(printMinutes, 0) / 60
    }
}
