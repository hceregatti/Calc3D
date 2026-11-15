import Calc3DCore
import SwiftUI

/// Lista e edição de propostas comerciais, separadas dos cálculos de impressão.
struct ProposalsView: View {
    @Environment(CalculatorViewModel.self) private var model

    var body: some View {
        @Bindable var model = model

        HStack(spacing: 0) {
            VStack(spacing: 0) {
                HStack {
                    Text("Propostas")
                        .font(.headline)
                    Spacer()
                    Button {
                        model.requestNewProposalDraft()
                    } label: {
                        Label("Nova", systemImage: "plus")
                    }
                    .help("Criar uma proposta comercial")
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
                    "Crie ou selecione uma proposta",
                    systemImage: "doc.text",
                    description: Text("Adicione produtos manualmente ou use cálculos já salvos.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .confirmationDialog(
            "Descartar alterações?",
            isPresented: Binding(
                get: { model.isConfirmingProposalDiscard },
                set: { if !$0 && model.isConfirmingProposalDiscard { model.cancelDiscardProposalDraft() } }
            ),
            titleVisibility: .visible
        ) {
            Button("Descartar e continuar", role: .destructive) {
                model.confirmDiscardProposalDraft()
            }
            Button("Continuar editando", role: .cancel) {
                model.cancelDiscardProposalDraft()
            }
        } message: {
            Text("As alterações não salvas nesta proposta serão perdidas.")
        }
        .confirmationDialog(
            "Excluir proposta?",
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
            Text("\(title.isEmpty ? "Esta proposta" : "\"\(title)\"") será removida permanentemente.")
        }
    }
}

private struct ProposalRow: View {
    let proposal: ProposalRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(proposal.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                 ? "Proposta sem título" : proposal.title)
                .font(.headline)
                .lineLimit(1)
            HStack {
                Text(proposal.updatedAt.formatted(date: .abbreviated, time: .shortened))
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
