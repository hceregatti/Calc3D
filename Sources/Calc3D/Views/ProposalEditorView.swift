import Calc3DCore
import SwiftUI

/// Editor de orçamento com itens independentes do cálculo de impressão.
struct ProposalEditorView: View {
    @Environment(CalculatorViewModel.self) private var model

    let proposal: ProposalRecord
    let onDelete: () -> Void

    var body: some View {
        @Bindable var model = model
        let isSaved = model.proposals.contains { $0.id == proposal.id }

        VStack(spacing: 0) {
            Form {
                Section("Orçamento") {
                    TextField("Título do orçamento", text: textBinding(\.title, in: model))
                    TextField("Cliente (opcional)", text: textBinding(\.customerName, in: model))
                    TextField("Contato (opcional)", text: textBinding(\.customerContact, in: model))
                    LabeledContent("Atualizada", value: proposal.updatedAt.formatted(date: .long, time: .shortened))
                }

                Section {
                    if proposal.items.isEmpty {
                        ContentUnavailableView(
                            "Nenhuma peça",
                            systemImage: "cube.box",
                            description: Text("Adicione peças do histórico ou itens manuais.")
                        )
                        .frame(minHeight: 120)
                    }

                    ForEach(proposal.items) { item in
                        ProposalItemEditor(item: item, model: model)
                    }

                    Button {
                        model.addManualItemToDraft()
                    } label: {
                        Label("Adicionar item manual", systemImage: "plus")
                    }

                    Button {
                        model.isPickingParts = true
                    } label: {
                        Label("Adicionar peças do histórico…", systemImage: "cube.box")
                    }
                    .disabled(model.quotes.isEmpty)
                } header: {
                    Text("Peças e itens")
                } footer: {
                    Text("Os valores ficam copiados no orçamento: alterar ou excluir a peça no histórico não muda este documento.")
                }

                Section {
                    LabeledContent("Total do orçamento", value: proposal.total.map(Currency.brl) ?? "Total excede o limite")
                        .font(.title3.bold())
                }
            }
            .formStyle(.grouped)

            HStack {
                if isSaved {
                    Button(role: .destructive, action: onDelete) {
                        Label("Excluir orçamento", systemImage: "trash")
                    }
                }
                Spacer()
                Button {
                    model.exportProposalPDF(proposal)
                } label: {
                    Label("Exportar PDF", systemImage: "doc.richtext")
                }
                .disabled(proposal.items.isEmpty || proposal.total == nil || !isSaved || model.proposalHasUnsavedChanges)
                .help("Salve o orçamento antes de exportar o PDF")
                Button {
                    model.saveProposalDraft()
                } label: {
                    Label("Salvar orçamento", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!model.proposalHasUnsavedChanges)
            }
            .padding(16)

            if let feedback = model.proposalPDFFeedback {
                Text(feedback)
                    .font(.caption)
                    .foregroundStyle(feedback.hasPrefix("PDF salvo") ? .green : .red)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
        }
        .navigationTitle(proposal.title.isEmpty ? "Novo orçamento" : proposal.title)
        .sheet(isPresented: $model.isPickingParts) {
            PartsPickerSheet { quotes in
                model.addQuotesToDraft(quotes)
            }
        }
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
                TextField("Peça ou item", text: binding(\.name))
                    .font(.headline)
                Spacer()
                Button(role: .destructive) {
                    model.deleteProposalItem(item.id)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Remover do orçamento")
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

            LabeledContent("Subtotal", value: item.subtotal.map(Currency.brl) ?? "Valor excede o limite")
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

/// Seleção de várias peças do histórico para incluir no orçamento.
private struct PartsPickerSheet: View {
    @Environment(CalculatorViewModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let onAdd: ([QuoteRecord]) -> Void

    var body: some View {
        @Bindable var model = model
        let selection = model.partsPickerSelection
        let visible = filteredQuotes
        let chosen = model.quotes(withIDs: selection)

        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Adicionar peças do histórico")
                    .font(.title3.bold())
                TextField("Buscar peça", text: $model.partsPickerSearch)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(16)

            List(visible) { quote in
                let enabled = CalculatorViewModel.canAddToProposal(quote)
                Toggle(isOn: Binding(
                    get: { selection.contains(quote.id) },
                    set: { if $0 { model.partsPickerSelection.insert(quote.id) } else { model.partsPickerSelection.remove(quote.id) } }
                )) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(quote.job.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                 ? "Peça sem nome" : quote.job.name)
                            Text(quote.savedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(quote.result.suggestedPrice.map(Currency.brl) ?? "Sem preço")
                            .monospacedDigit()
                    }
                }
                .toggleStyle(.checkbox)
                .disabled(!enabled)
                .padding(.vertical, 2)
            }
            .overlay {
                if visible.isEmpty {
                    ContentUnavailableView.search(text: model.partsPickerSearch)
                }
            }

            Divider()
            HStack {
                Button(selection.isEmpty ? "Selecionar todas" : "Limpar seleção") {
                    if selection.isEmpty {
                        model.partsPickerSelection = Set(visible.filter(CalculatorViewModel.canAddToProposal).map(\.id))
                    } else {
                        model.partsPickerSelection = []
                    }
                }
                Spacer()
                Button("Cancelar", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(chosen.count > 1 ? "Adicionar \(chosen.count) peças" : "Adicionar") {
                    onAdd(chosen)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(chosen.isEmpty)
            }
            .padding(16)
        }
        .frame(width: 480, height: 520)
    }

    private var filteredQuotes: [QuoteRecord] {
        let term = model.partsPickerSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return model.quotes }
        return model.quotes.filter { $0.job.name.localizedCaseInsensitiveContains(term) }
    }
}

