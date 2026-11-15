import Calc3DCore
import SwiftUI

/// Editor explícito de proposta com itens independentes do cálculo de impressão.
struct ProposalEditorView: View {
    @Environment(CalculatorViewModel.self) private var model

    let proposal: ProposalRecord
    let onDelete: () -> Void

    var body: some View {
        @Bindable var model = model
        let isSaved = model.proposals.contains { $0.id == proposal.id }

        VStack(spacing: 0) {
            Form {
                Section("Proposta") {
                    TextField("Título da proposta", text: textBinding(\.title, in: model))
                    TextField("Cliente (opcional)", text: textBinding(\.customerName, in: model))
                    TextField("Contato (opcional)", text: textBinding(\.customerContact, in: model))
                    LabeledContent("Atualizada", value: proposal.updatedAt.formatted(date: .long, time: .shortened))
                }

                Section {
                    if proposal.items.isEmpty {
                        ContentUnavailableView(
                            "Nenhum produto",
                            systemImage: "shippingbox",
                            description: Text("Adicione produtos manualmente ou a partir de um cálculo salvo.")
                        )
                        .frame(minHeight: 120)
                    }

                    ForEach(proposal.items) { item in
                        ProposalItemEditor(item: item, model: model)
                    }

                    Button {
                        model.addManualItemToDraft()
                    } label: {
                        Label("Adicionar produto manual", systemImage: "plus")
                    }
                } header: {
                    Text("Produtos")
                } footer: {
                    Text("Os valores deste documento ficam independentes dos cálculos de impressão.")
                }

                Section {
                    LabeledContent("Total da proposta", value: Currency.brl(proposal.total))
                        .font(.title3.bold())
                }
            }
            .formStyle(.grouped)

            HStack {
                if isSaved {
                    Button(role: .destructive, action: onDelete) {
                        Label("Excluir proposta", systemImage: "trash")
                    }
                }
                Spacer()
                Button {
                    model.saveProposalDraft()
                } label: {
                    Label("Salvar proposta", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!model.proposalHasUnsavedChanges)
            }
            .padding(16)
        }
        .navigationTitle(proposal.title.isEmpty ? "Nova proposta" : proposal.title)
    }

    private func textBinding(
        _ keyPath: WritableKeyPath<ProposalRecord, String>,
        in model: CalculatorViewModel
    ) -> Binding<String> {
        Binding(
            get: { model.proposalDraft?[keyPath: keyPath] ?? "" },
            set: { value in model.updateProposalDraft { $0[keyPath: keyPath] = value } }
        )
    }
}

private struct ProposalItemEditor: View {
    let item: ProposalItem
    let model: CalculatorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                TextField("Produto", text: binding(\.name))
                    .font(.headline)
                Spacer()
                Button(role: .destructive) {
                    model.deleteProposalItem(item.id)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Remover produto da proposta")
            }

            TextField("Descrição (opcional)", text: binding(\.details))
                .font(.callout)

            HStack {
                Stepper(value: binding(\.quantity), in: 1...9999) {
                    Text("Quantidade: \(item.quantity)")
                        .monospacedDigit()
                }
                Spacer()
                TextField("Preço unitário", value: priceBinding, format: .number.precision(.fractionLength(2)))
                    .multilineTextAlignment(.trailing)
                    .frame(width: 110)
                Text("R$")
                    .foregroundStyle(.secondary)
            }

            LabeledContent("Subtotal", value: Currency.brl(item.subtotal))
                .font(.callout.bold())
        }
        .padding(.vertical, 6)
    }

    private var priceBinding: Binding<Double> {
        Binding(
            get: { item.unitPrice },
            set: { value in
                model.updateProposalItem(item.id) { $0.unitPrice = value }
            }
        )
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<ProposalItem, Value>) -> Binding<Value> {
        Binding(
            get: { item[keyPath: keyPath] },
            set: { value in model.updateProposalItem(item.id) { $0[keyPath: keyPath] = value } }
        )
    }
}
