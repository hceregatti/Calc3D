import Foundation

/// Item comercial independente, com valores copiados no momento da inclusão.
struct ProposalItem: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String
    var details: String
    var quantity: Int
    var unitPrice: Double
    let sourceQuoteID: UUID?

    var subtotal: Double { Double(max(quantity, 1)) * (unitPrice.isFinite ? max(unitPrice, 0) : 0) }

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
        self.quantity = max(quantity, 1)
        self.unitPrice = unitPrice.isFinite ? max(unitPrice, 0) : 0
        self.sourceQuoteID = sourceQuoteID
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

    var total: Double { items.reduce(0) { $0 + $1.subtotal } }

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
