import Foundation

/// Dados de uma impressão específica (normalmente tirados do fatiador).
///
/// Peso e tempo referem-se à mesa inteira; o custo é dividido por `partsPerPlate`.
public struct PrintJob: Codable, Equatable, Sendable {
    /// Nome da peça ou do pedido, usado no orçamento.
    public var name: String = ""
    /// Peso de filamento informado pelo fatiador para a mesa (g).
    public var partWeight: Double = 85
    /// Desperdício com purga, skirt/brim e troca de cor (%).
    public var wastePercent: Double = 5
    public var printHours: Double = 6
    public var printMinutes: Double = 30
    /// Quantidade de peças impressas na mesma mesa.
    public var partsPerPlate: Int = 1
    /// Fatiar, preparar mesa, retirar peça (min).
    public var setupMinutes: Double = 15
    /// Remover suportes, lixar, pintar (min).
    public var postProcessingMinutes: Double = 20
    /// Cola, lixa, tinta, primer, ímãs etc. para esta mesa (R$).
    public var consumablesPerPlate: Double = 2
    /// Margem de lucro sobre o preço de venda (%), não markup.
    public var marginPercent: Double = 40

    /// Filamento da biblioteca usado nesta peça; nil usa o filamento padrão dos parâmetros fixos.
    public var filamentID: UUID?
    /// Nome do filamento no momento da escolha (para exibir mesmo se for excluído da biblioteca).
    public var filamentName: String?
    /// Preço por grama do filamento escolhido (R$/g); substitui o do rolo padrão.
    public var filamentPricePerGram: Double?

    public init() {}

    public static let defaults = PrintJob()

    /// Tempo total de impressão em horas.
    public var totalPrintHours: Double {
        Sanitize.nonNegative(printHours) + Sanitize.nonNegative(printMinutes) / 60
    }
}

enum Sanitize {
    static func nonNegative(_ v: Double) -> Double { v.isFinite ? max(v, 0) : 0 }
    static func atLeastOne(_ v: Double) -> Double { v.isFinite ? max(v, 1) : 1 }
}
