import Calc3DCore
import SwiftUI

/// Lista e edição de orçamentos, montados a partir do histórico de peças.
struct ProposalsView: View {
    @Environment(CalculatorViewModel.self) private var model

    var body: some View {
        @Bindable var model = model

        HStack(spacing: 0) {
            VStack(spacing: 0) {
                HStack {
                    Text("Orçamentos")
                        .font(.headline)
                    Spacer()
                    Button {
                        model.requestNewProposalDraft()
                    } label: {
                        Label("Novo", systemImage: "plus.circle.fill")
                    }
                    .help("Criar um orçamento")
                }
                .padding(12)

                Picker("Situação", selection: $model.proposalFilter) {
                    ForEach(ProposalStatus.allCases, id: \.self) { status in
                        Text("\(status.title) (\(model.proposals(in: status).count))").tag(status)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(.horizontal, 12)
                .padding(.bottom, 8)

                let shown = model.proposals(in: model.proposalFilter)
                List(selection: $model.selectedProposalID) {
                    ForEach(shown) { proposal in
                        ProposalRow(proposal: proposal)
                            .tag(proposal.id)
                    }
                }
                .overlay {
                    if shown.isEmpty {
                        ContentUnavailableView {
                            Label(emptyTitle(model.proposalFilter), systemImage: model.proposalFilter.systemImage)
                        } description: {
                            Text(emptyText(model.proposalFilter))
                        }
                    }
                }
                Divider()
                HStack {
                    Text(totalLabel(model.proposalFilter))
                    Spacer()
                    Text(Currency.format(model.proposalsTotal(in: model.proposalFilter))).monospacedDigit()
                }
                .font(.caption)
                .foregroundStyle(Theme.muted)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .onChange(of: model.selectedProposalID) { _, proposalID in
                    if let proposalID {
                        model.requestOpenProposal(proposalID)
                    }
                }
            }
            .frame(minWidth: 240, idealWidth: 290, maxWidth: 340)

            Divider()

            if let proposal = model.proposalDraft {
                ProposalEditorView(proposal: proposal) {
                    model.proposalPendingDeletionID = proposal.id
                }
            } else {
                ContentUnavailableView(
                    "Crie ou selecione um orçamento",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Monte orçamentos com várias peças do histórico ou itens manuais.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Orçamentos")
        .confirmationDialog(
            "Excluir orçamento?",
            isPresented: Binding(
                get: { model.proposalPendingDeletionID != nil },
                set: { if !$0 { model.proposalPendingDeletionID = nil } }
            ),
            titleVisibility: .visible,
            presenting: model.proposalPendingDeletionID
        ) { proposalID in
            Button("Excluir", role: .destructive) {
                if let proposal = model.proposals.first(where: { $0.id == proposalID }) {
                    model.deleteProposal(proposal)
                }
                model.proposalPendingDeletionID = nil
            }
        } message: { proposalID in
            let title = model.proposals.first(where: { $0.id == proposalID })?.title ?? ""
            Text("\(title.isEmpty ? "Este orçamento" : "\"\(title)\"") será removido permanentemente.")
        }
    }

    private func emptyTitle(_ status: ProposalStatus) -> String {
        switch status {
        case .waiting: "Nada aguardando"
        case .expired: "Nenhum vencido"
        case .sold: "Nenhuma venda"
        }
    }

    private func emptyText(_ status: ProposalStatus) -> String {
        switch status {
        case .waiting: "Orçamentos salvos aguardam aqui até serem aprovados ou vencerem."
        case .expired: "Orçamentos que passam da validade sem aprovação saem da fila e vêm para cá."
        case .sold: "Confirme a venda de um orçamento para vê-lo aqui."
        }
    }

    private func totalLabel(_ status: ProposalStatus) -> String {
        switch status {
        case .waiting: "Em aberto"
        case .expired: "Perdido por validade"
        case .sold: "Total vendido"
        }
    }
}

private struct ProposalRow: View {
    let proposal: ProposalRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(proposal.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                 ? "Orçamento sem título" : proposal.title)
                .font(.headline)
                .lineLimit(1)
            HStack {
                Text("\(proposal.items.count) \(proposal.items.count == 1 ? "item" : "itens") · \(proposal.updatedAt.formatted(date: .abbreviated, time: .omitted))")
                Spacer()
                Text(proposal.total.map(Currency.format) ?? "Total inválido")
                    .monospacedDigit()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            Text(statusText)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(statusColor)
        }
        .padding(.vertical, 4)
    }

    private var statusText: String {
        switch proposal.status() {
        case .sold:
            return "Venda em " + (proposal.saleConfirmedAt ?? proposal.updatedAt).formatted(date: .abbreviated, time: .omitted)
        case .expired:
            let days = -(proposal.daysUntilExpiry() ?? 0)
            return days == 1 ? "Venceu ontem" : "Venceu há \(days) dias"
        case .waiting:
            guard let days = proposal.daysUntilExpiry() else { return "Sem validade" }
            return days == 0 ? "Vence hoje" : days == 1 ? "Vence amanhã" : "Vence em \(days) dias"
        }
    }

    private var statusColor: Color {
        switch proposal.status() {
        case .sold: Theme.success
        case .expired: Theme.danger
        case .waiting: (proposal.daysUntilExpiry() ?? 99) <= 2 ? Theme.warn : Theme.muted
        }
    }
}
