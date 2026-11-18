import Calc3DCore
import Foundation

extension ProposalStatus {
    var title: String {
        switch self {
        case .waiting: "Aguardando"
        case .expired: "Vencidos"
        case .sold: "Vendas"
        }
    }

    var systemImage: String {
        switch self {
        case .waiting: "hourglass"
        case .expired: "clock.badge.xmark"
        case .sold: "checkmark.seal.fill"
        }
    }
}

extension CalculatorViewModel {
    /// Orçamentos salvos de uma aba, na ordem mais útil para cada uma.
    func proposals(in status: ProposalStatus, now: Date = .now) -> [ProposalRecord] {
        let list = proposals.filter { $0.status(now: now) == status }
        switch status {
        case .waiting:
            // Os que vencem primeiro ficam no topo; sem validade vão para o fim.
            return list.sorted { ($0.validUntil ?? .distantFuture) < ($1.validUntil ?? .distantFuture) }
        case .expired:
            return list.sorted { ($0.validUntil ?? .distantPast) > ($1.validUntil ?? .distantPast) }
        case .sold:
            return list.sorted { ($0.saleConfirmedAt ?? .distantPast) > ($1.saleConfirmedAt ?? .distantPast) }
        }
    }

    /// Soma dos totais de uma aba (ignora totais inválidos).
    func proposalsTotal(in status: ProposalStatus) -> Double {
        proposals(in: status).compactMap(\.total).reduce(0, +)
    }

    /// Marca o orçamento como venda confirmada e salva.
    func confirmSale(for proposal: ProposalRecord) {
        var proposal = proposal
        proposal.saleConfirmedAt = .now
        saveProposal(proposal)
        proposalDraft = proposals.first { $0.id == proposal.id }
        proposalFilter = .sold
    }

    /// Desfaz a venda: o orçamento volta para a fila (ou para os vencidos, se o prazo já passou).
    func reopenProposal(_ proposal: ProposalRecord) {
        var proposal = proposal
        proposal.saleConfirmedAt = nil
        saveProposal(proposal)
        proposalDraft = proposals.first { $0.id == proposal.id }
        proposalFilter = proposalDraft?.status() ?? .waiting
    }

    /// Renova a validade a partir de hoje e devolve o orçamento vencido para a fila.
    func renewProposal(_ proposal: ProposalRecord) {
        // Salvar já reinicia a contagem da validade (updatedAt).
        saveProposal(proposal)
        proposalDraft = proposals.first { $0.id == proposal.id }
        proposalFilter = proposalDraft?.status() ?? .waiting
    }
}
