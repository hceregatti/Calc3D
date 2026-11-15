import Foundation

/// Dados da empresa e padrões usados para personalizar os orçamentos.
struct CompanyProfile: Codable, Equatable, Sendable {
    // Identidade
    var logoImageID: UUID?
    var companyName = ""
    var document = ""
    var responsibleName = ""

    // Contato
    var phone = ""
    var whatsapp = ""
    var email = ""
    var website = ""
    var instagram = ""
    var address = ""

    // Aparência do PDF
    var accentHex = "#1E6FD9"
    var showProductPhotos = true

    // Padrões para novos orçamentos
    var nextProposalNumber = 1
    var defaultValidityDays = 15
    var defaultPaymentTerms = "Pix, cartão de crédito ou boleto. 50% de entrada e 50% na entrega."
    var defaultDeliveryTime = "Até 7 dias úteis após a aprovação."
    var defaultNotes = ""
    var footerText = "Obrigado pela preferência!"

    static let defaults = CompanyProfile()

    init() {}

    /// Decodifica campo a campo para que novas propriedades não invalidem dados salvos.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Self.defaults
        logoImageID = try c.decodeIfPresent(UUID.self, forKey: .logoImageID)
        companyName = try c.decodeIfPresent(String.self, forKey: .companyName) ?? d.companyName
        document = try c.decodeIfPresent(String.self, forKey: .document) ?? d.document
        responsibleName = try c.decodeIfPresent(String.self, forKey: .responsibleName) ?? d.responsibleName
        phone = try c.decodeIfPresent(String.self, forKey: .phone) ?? d.phone
        whatsapp = try c.decodeIfPresent(String.self, forKey: .whatsapp) ?? d.whatsapp
        email = try c.decodeIfPresent(String.self, forKey: .email) ?? d.email
        website = try c.decodeIfPresent(String.self, forKey: .website) ?? d.website
        instagram = try c.decodeIfPresent(String.self, forKey: .instagram) ?? d.instagram
        address = try c.decodeIfPresent(String.self, forKey: .address) ?? d.address
        accentHex = try c.decodeIfPresent(String.self, forKey: .accentHex) ?? d.accentHex
        showProductPhotos = try c.decodeIfPresent(Bool.self, forKey: .showProductPhotos) ?? d.showProductPhotos
        nextProposalNumber = try c.decodeIfPresent(Int.self, forKey: .nextProposalNumber) ?? d.nextProposalNumber
        defaultValidityDays = try c.decodeIfPresent(Int.self, forKey: .defaultValidityDays) ?? d.defaultValidityDays
        defaultPaymentTerms = try c.decodeIfPresent(String.self, forKey: .defaultPaymentTerms) ?? d.defaultPaymentTerms
        defaultDeliveryTime = try c.decodeIfPresent(String.self, forKey: .defaultDeliveryTime) ?? d.defaultDeliveryTime
        defaultNotes = try c.decodeIfPresent(String.self, forKey: .defaultNotes) ?? d.defaultNotes
        footerText = try c.decodeIfPresent(String.self, forKey: .footerText) ?? d.footerText
    }

    private enum CodingKeys: String, CodingKey {
        case logoImageID, companyName, document, responsibleName
        case phone, whatsapp, email, website, instagram, address
        case accentHex, showProductPhotos
        case nextProposalNumber, defaultValidityDays, defaultPaymentTerms, defaultDeliveryTime, defaultNotes, footerText
    }
}
