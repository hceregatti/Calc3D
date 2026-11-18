import Calc3DCore
import Foundation

/// Item comercial independente, com valores copiados no momento da inclusão.
struct ProposalItem: Codable, Identifiable, Equatable, Sendable {
    static let maxQuantity = 9999
    private static let maxUnitPriceCents = Int64.max / Int64(maxQuantity)

    let id: UUID
    var name: String
    var details: String
    var quantity: Int
    private(set) var unitPriceCents: Int64
    let sourceQuoteID: UUID?
    /// Foto do produto (arquivo no ImageStore). Sem foto, usa a imagem padrão.
    var imageID: UUID?
    /// Filamento da biblioteca usado na peça e consumo por unidade (g), copiados na inclusão.
    var filamentID: UUID?
    var filamentName: String?
    var gramsPerUnit: Double?

    var unitPrice: Double {
        get { Double(unitPriceCents) / 100 }
        set { unitPriceCents = Self.cents(for: newValue) }
    }

    var subtotalCents: Int64? {
        guard quantity > 0, quantity <= Self.maxQuantity,
              unitPriceCents >= 0, unitPriceCents <= Self.maxUnitPriceCents
        else { return nil }
        let (subtotal, overflow) = unitPriceCents.multipliedReportingOverflow(by: Int64(quantity))
        return overflow ? nil : subtotal
    }

    var subtotal: Double? { subtotalCents.map { Double($0) / 100 } }

    init(
        id: UUID = UUID(),
        name: String,
        details: String = "",
        quantity: Int = 1,
        unitPrice: Double,
        sourceQuoteID: UUID? = nil,
        imageID: UUID? = nil,
        filamentID: UUID? = nil,
        filamentName: String? = nil,
        gramsPerUnit: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.details = details
        self.quantity = min(max(quantity, 1), Self.maxQuantity)
        self.unitPriceCents = Self.cents(for: unitPrice)
        self.sourceQuoteID = sourceQuoteID
        self.imageID = imageID
        self.filamentID = filamentID
        self.filamentName = filamentName
        self.gramsPerUnit = gramsPerUnit
    }

    static func cents(for value: Double) -> Int64 {
        guard value.isFinite, value > 0 else { return 0 }
        let maximum = Double(maxUnitPriceCents)
        let roundedCents = value >= maximum / 100 ? maximum : (value * 100).rounded(.toNearestOrAwayFromZero)
        return Int64(min(roundedCents, maximum))
    }
}

/// Proposta comercial local, independente dos dados da impressão.
struct ProposalRecord: Codable, Identifiable, Equatable, Sendable {
    static let maxAdjustmentCents: Int64 = 100_000_000_000

    let id: UUID
    /// Número sequencial, atribuído no primeiro salvamento.
    var number: Int?
    var title: String
    let createdAt: Date
    var updatedAt: Date

    // Cliente
    var customerName: String
    var customerContact: String
    var customerDocument: String
    var customerAddress: String

    var items: [ProposalItem]

    // Ajustes do total
    private(set) var discountCents: Int64
    private(set) var shippingCents: Int64

    // Condições comerciais (vazias não aparecem no PDF)
    var validityDays: Int
    var paymentTerms: String
    var deliveryTime: String
    var notes: String

    /// Baixas feitas no estoque de filamento por este orçamento (vazio = ainda não baixado).
    var stockDeductions: [StockDeduction] = []

    /// Quando a venda foi confirmada; nil = ainda não vendido.
    var saleConfirmedAt: Date?

    var hasStockDeduction: Bool { !stockDeductions.isEmpty }

    /// Consumo de filamento previsto, somado por rolo.
    var filamentRequirements: [FilamentUsage.Requirement] {
        FilamentUsage.requirements(items.map {
            .init(filamentID: $0.filamentID, filamentName: $0.filamentName ?? "", gramsPerUnit: $0.gramsPerUnit, quantity: $0.quantity)
        })
    }

    var discount: Double {
        get { Double(discountCents) / 100 }
        set { discountCents = min(ProposalItem.cents(for: newValue), Self.maxAdjustmentCents) }
    }

    var shipping: Double {
        get { Double(shippingCents) / 100 }
        set { shippingCents = min(ProposalItem.cents(for: newValue), Self.maxAdjustmentCents) }
    }

    var itemsTotalCents: Int64? {
        var total: Int64 = 0
        for item in items {
            guard let subtotal = item.subtotalCents else { return nil }
            let (sum, overflow) = total.addingReportingOverflow(subtotal)
            guard !overflow else { return nil }
            total = sum
        }
        return total
    }

    var itemsTotal: Double? { itemsTotalCents.map { Double($0) / 100 } }

    var totalCents: Int64? {
        guard let items = itemsTotalCents else { return nil }
        let (withShipping, overflow) = items.addingReportingOverflow(shippingCents)
        guard !overflow else { return nil }
        return max(0, withShipping - discountCents)
    }

    var total: Double? { totalCents.map { Double($0) / 100 } }

    var formattedNumber: String? {
        number.map { String(format: "%04d", $0) }
    }

    var validUntil: Date? {
        ProposalStatus.validUntil(updatedAt: updatedAt, validityDays: validityDays)
    }

    func status(now: Date = .now) -> ProposalStatus {
        ProposalStatus.evaluate(updatedAt: updatedAt, validityDays: validityDays, saleConfirmedAt: saleConfirmedAt, now: now)
    }

    /// Dias até vencer (0 = hoje, negativo = vencido); nil sem validade.
    func daysUntilExpiry(now: Date = .now) -> Int? {
        ProposalStatus.daysUntilExpiry(updatedAt: updatedAt, validityDays: validityDays, now: now)
    }

    init(
        id: UUID = UUID(),
        number: Int? = nil,
        title: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now,
        customerName: String = "",
        customerContact: String = "",
        customerDocument: String = "",
        customerAddress: String = "",
        items: [ProposalItem] = [],
        validityDays: Int = 0,
        paymentTerms: String = "",
        deliveryTime: String = "",
        notes: String = ""
    ) {
        self.id = id
        self.number = number
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.customerName = customerName
        self.customerContact = customerContact
        self.customerDocument = customerDocument
        self.customerAddress = customerAddress
        self.items = items
        self.discountCents = 0
        self.shippingCents = 0
        self.validityDays = validityDays
        self.paymentTerms = paymentTerms
        self.deliveryTime = deliveryTime
        self.notes = notes
    }

    /// Orçamento novo já preenchido com os padrões da empresa.
    init(defaultsFrom profile: CompanyProfile, title: String = "Novo orçamento") {
        self.init(
            title: title,
            validityDays: profile.defaultValidityDays,
            paymentTerms: profile.defaultPaymentTerms,
            deliveryTime: profile.defaultDeliveryTime,
            notes: profile.defaultNotes
        )
    }

    /// Campos novos são opcionais no JSON para manter os orçamentos já salvos.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        number = try c.decodeIfPresent(Int.self, forKey: .number)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        customerName = try c.decodeIfPresent(String.self, forKey: .customerName) ?? ""
        customerContact = try c.decodeIfPresent(String.self, forKey: .customerContact) ?? ""
        customerDocument = try c.decodeIfPresent(String.self, forKey: .customerDocument) ?? ""
        customerAddress = try c.decodeIfPresent(String.self, forKey: .customerAddress) ?? ""
        items = try c.decodeIfPresent([ProposalItem].self, forKey: .items) ?? []
        discountCents = max(0, min(try c.decodeIfPresent(Int64.self, forKey: .discountCents) ?? 0, Self.maxAdjustmentCents))
        shippingCents = max(0, min(try c.decodeIfPresent(Int64.self, forKey: .shippingCents) ?? 0, Self.maxAdjustmentCents))
        validityDays = try c.decodeIfPresent(Int.self, forKey: .validityDays) ?? 0
        paymentTerms = try c.decodeIfPresent(String.self, forKey: .paymentTerms) ?? ""
        deliveryTime = try c.decodeIfPresent(String.self, forKey: .deliveryTime) ?? ""
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        stockDeductions = try c.decodeIfPresent([StockDeduction].self, forKey: .stockDeductions) ?? []
        saleConfirmedAt = try c.decodeIfPresent(Date.self, forKey: .saleConfirmedAt)
    }

    private enum CodingKeys: String, CodingKey {
        case id, number, title, createdAt, updatedAt
        case customerName, customerContact, customerDocument, customerAddress
        case items, discountCents, shippingCents
        case validityDays, paymentTerms, deliveryTime, notes, stockDeductions, saleConfirmedAt
    }
}
