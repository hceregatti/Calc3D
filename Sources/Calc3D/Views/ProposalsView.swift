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

                List(selection: $model.selectedProposalID) {
                    ForEach(model.proposals) { proposal in
                        ProposalRow(proposal: proposal)
                            .tag(proposal.id)
                    }
                }
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
                Text(proposal.total.map(Currency.brl) ?? "Total inválido")
                    .monospacedDigit()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
