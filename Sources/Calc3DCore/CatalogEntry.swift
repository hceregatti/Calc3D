import Foundation

/// Uma peça publicada no catálogo compartilhado, com os parâmetros que o autor usou.
public struct CatalogEntry: Codable, Identifiable, Equatable, Sendable {
    /// Versão do formato do arquivo; entradas de versão maior que esta são ignoradas.
    public static let currentSchema = 1

    public var schemaVersion: Int
    /// Igual ao id da peça no histórico do autor, então publicar de novo atualiza a mesma entrada.
    public var id: UUID
    public var authorID: UUID
    public var authorName: String
    public var publishedAt: Date
    public var updatedAt: Date
    public var note: String
    public var job: PrintJob
    /// Parâmetros fixos do autor na época da publicação.
    public var settings: ShopSettings
    public var result: CostResult

    public init(
        id: UUID, authorID: UUID, authorName: String, note: String = "",
        job: PrintJob, settings: ShopSettings, result: CostResult,
        publishedAt: Date = .now, updatedAt: Date = .now
    ) {
        self.schemaVersion = Self.currentSchema
        self.id = id
        self.authorID = authorID
        self.authorName = authorName
        self.note = note
        self.job = job
        self.settings = settings
        self.result = result
        self.publishedAt = publishedAt
        self.updatedAt = updatedAt
    }

    /// Campos opcionais tolerantes, para o formato poder crescer sem invalidar entradas já publicadas.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        id = try c.decode(UUID.self, forKey: .id)
        authorID = try c.decode(UUID.self, forKey: .authorID)
        authorName = try c.decodeIfPresent(String.self, forKey: .authorName) ?? ""
        publishedAt = try c.decode(Date.self, forKey: .publishedAt)
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? publishedAt
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        job = try c.decode(PrintJob.self, forKey: .job)
        settings = try c.decode(ShopSettings.self, forKey: .settings)
        result = try c.decode(CostResult.self, forKey: .result)
    }

    /// Peça sem o vínculo com o filamento do autor (que não existe na biblioteca de quem a usa):
    /// vale o filamento padrão dos parâmetros de quem está vendo.
    public var localJob: PrintJob {
        var local = job
        local.filamentID = nil
        local.filamentName = nil
        local.filamentPricePerGram = nil
        return local
    }

    public var authorPrice: Double? { result.suggestedPrice }

    /// Preço e custo da peça com os parâmetros de quem está vendo.
    public func comparison(with settings: ShopSettings) -> PriceComparison {
        let mine = CostCalculator.calculate(settings: settings, job: localJob)
        return PriceComparison(
            authorPrice: result.suggestedPrice, authorUnitCost: result.unitCost,
            myPrice: mine.suggestedPrice, myUnitCost: mine.unitCost, myResult: mine
        )
    }
}

public struct PriceComparison: Sendable {
    public var authorPrice: Double?
    public var authorUnitCost: Double
    public var myPrice: Double?
    public var myUnitCost: Double
    public var myResult: CostResult

    /// Diferença (meu preço − preço do autor); nil se algum dos dois não existe.
    public var priceDelta: Double? {
        guard let authorPrice, let myPrice else { return nil }
        return myPrice - authorPrice
    }
}
