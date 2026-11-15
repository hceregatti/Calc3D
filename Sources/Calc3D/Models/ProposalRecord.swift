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
        sourceQuoteID: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.details = details
        self.quantity = min(max(quantity, 1), Self.maxQuantity)
        self.unitPriceCents = Self.cents(for: unitPrice)
        self.sourceQuoteID = sourceQuoteID
    }

    private static func cents(for value: Double) -> Int64 {
        guard value.isFinite, value > 0 else { return 0 }
        let maximum = Double(maxUnitPriceCents)
        let roundedCents = value >= maximum / 100 ? maximum : (value * 100).rounded(.toNearestOrAwayFromZero)
        return Int64(min(roundedCents, maximum))
    }
}

/// Proposta comercial local, independente dos dados da impressão.
struct ProposalRecord: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var title: String
    let createdAt: Date
    var updatedAt: Date
    var customerName: String
    var customerContact: String
    var items: [ProposalItem]

    var totalCents: Int64? {
        var total: Int64 = 0
        for item in items {
            guard let subtotal = item.subtotalCents else { return nil }
            let (sum, overflow) = total.addingReportingOverflow(subtotal)
            guard !overflow else { return nil }
            total = sum
        }
        return total
    }

    var total: Double? { totalCents.map { Double($0) / 100 } }

    init(
        id: UUID = UUID(),
        title: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now,
        customerName: String = "",
        customerContact: String = "",
        items: [ProposalItem] = []
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.customerName = customerName
        self.customerContact = customerContact
        self.items = items
    }
}
