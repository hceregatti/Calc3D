import Calc3DCore
import SwiftUI

/// Histórico de cálculos de peças, com seleção múltipla para gerar orçamentos.
struct PartsView: View {
    @Environment(CalculatorViewModel.self) private var model

    var body: some View {
        @Bindable var model = model
        let selected = model.quotes(withIDs: model.selectedQuoteIDs)

        HStack(spacing: 0) {
            VStack(spacing: 0) {
                SelectionList(items: model.quotes, selection: $model.selectedQuoteIDs) { quote in
                    QuoteRow(quote: quote)
                        .contextMenu {
                            Button("Usar como base") { model.useQuoteAsBase(quote) }
                                .pointerCursor()
                            AddToProposalMenu(quotes: contextQuotes(for: quote))
                            Divider()
                            Button("Excluir…", role: .destructive) {
                                model.quotePendingDeletionID = quote.id
                            }
                                .pointerCursor()
                        }
                }
                .overlay {
                    if model.quotes.isEmpty {
                        ContentUnavailableView {
                            Label("Nenhuma peça salva", systemImage: "square.stack.3d.up.slash")
                        } description: {
                            Text("Calcule uma peça e clique em “Salvar peça” para guardá-la aqui.")
                        } actions: {
                            Button("Calcular peça") { model.newJob() }
                                .pointerCursor()
                        }
                    }
                }

                Divider()
                HStack {
                    Text(model.quotes.isEmpty ? "" : "⌘-clique ou ⇧-clique para selecionar várias")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(model.selectedQuoteIDs.count == model.quotes.count && !model.quotes.isEmpty
                           ? "Limpar" : "Selecionar todas") {
                        if model.selectedQuoteIDs.count == model.quotes.count {
                            model.selectedQuoteIDs = []
                        } else {
                            model.selectedQuoteIDs = Set(model.quotes.map(\.id))
                        }
                    }
                    .buttonStyle(.subtleLink)
                    .font(.caption)
                    .disabled(model.quotes.isEmpty)
                        .pointerCursor()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .frame(minWidth: 260, idealWidth: 300, maxWidth: 360)

            Divider()

            if selected.count == 1, let quote = selected.first {
                QuoteDetail(
                    quote: quote,
                    nameDraft: Binding(
                        get: { model.quoteNameDraftID == quote.id ? model.quoteNameDraft : quote.job.name },
                        set: { model.updateQuoteNameDraft($0, for: quote.id) }
                    ),
                    canSaveName: model.quoteNameHasUnsavedChanges(for: quote),
                    onSaveName: { model.saveQuoteName(for: quote) },
                    useAsBase: { model.useQuoteAsBase(quote) },
                    onDelete: { model.quotePendingDeletionID = quote.id }
                )
            } else if selected.count > 1 {
                MultiplePartsSummary(quotes: selected)
            } else if !model.quotes.isEmpty {
                ContentUnavailableView(
                    "Selecione peças",
                    systemImage: "square.stack.3d.up",
                    description: Text("Selecione uma peça para ver os detalhes, ou várias para gerar um orçamento.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Peças")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    model.newJob()
                } label: {
                    Label("Calcular peça", systemImage: "plus.circle.fill")
                }
                .help("Calcular uma nova peça")
                    .pointerCursor()

                Button {
                    model.addQuotesToProposal(selected, proposalID: nil)
                } label: {
                    Label("Gerar orçamento", systemImage: "doc.badge.plus")
                }
                .disabled(!selected.contains(where: CalculatorViewModel.canAddToProposal))
                .help("Cria um orçamento com as peças selecionadas")
                    .pointerCursor()
            }
        }
        .confirmationDialog(
            "Excluir peça?",
            isPresented: Binding(
                get: { model.quotePendingDeletionID != nil },
                set: { if !$0 { model.quotePendingDeletionID = nil } }
            ),
            titleVisibility: .visible,
            presenting: model.quotePendingDeletionID
        ) { quoteID in
            Button("Excluir", role: .destructive) {
                if let quote = model.quotes.first(where: { $0.id == quoteID }) {
                    model.deleteQuote(quote)
                }
                model.quotePendingDeletionID = nil
            }
                .pointerCursor()
        } message: { quoteID in
            let name = model.quotes.first(where: { $0.id == quoteID })?.job.name ?? ""
            Text("\(name.isEmpty ? "Esta peça" : "\"\(name)\"") será removida do histórico. Orçamentos já criados não mudam.")
        }
    }

    /// No menu de contexto, age sobre a seleção quando a linha faz parte dela.
    private func contextQuotes(for quote: QuoteRecord) -> [QuoteRecord] {
        model.selectedQuoteIDs.contains(quote.id) ? model.quotes(withIDs: model.selectedQuoteIDs) : [quote]
    }
}

/// Menu para criar um orçamento novo ou incluir as peças em um existente.
struct AddToProposalMenu: View {
    @Environment(CalculatorViewModel.self) private var model
    let quotes: [QuoteRecord]

    var body: some View {
        let count = quotes.filter(CalculatorViewModel.canAddToProposal).count
        Menu(count > 1 ? "Adicionar \(count) peças a orçamento" : "Adicionar a orçamento") {
            Button {
                model.addQuotesToProposal(quotes, proposalID: nil)
            } label: {
                Label("Novo orçamento", systemImage: "doc.badge.plus")
            }
            if !model.proposals.isEmpty {
                Section("Orçamentos existentes") {
                    ForEach(model.proposals) { proposal in
                        let title = proposal.title.trimmingCharacters(in: .whitespacesAndNewlines)
                        Button(title.isEmpty ? "Orçamento sem título" : title) {
                            model.addQuotesToProposal(quotes, proposalID: proposal.id)
                        }
                    }
                }
            }
        }
        .disabled(count == 0)
            .pointerCursor()
    }
}

private struct MultiplePartsSummary: View {
    @Environment(CalculatorViewModel.self) private var model
    let quotes: [QuoteRecord]

    var body: some View {
        let priced = quotes.filter(CalculatorViewModel.canAddToProposal)
        let total = priced.compactMap(\.result.suggestedPrice).reduce(0, +)

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(quotes.count) peças selecionadas")
                        .font(.title2.bold())
                    Text("Gere um orçamento com todas elas, uma unidade de cada. Você ajusta quantidades e preços depois.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                GroupBox {
                    ForEach(quotes) { quote in
                        HStack {
                            Text(quote.job.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                 ? "Peça sem nome" : quote.job.name)
                            Spacer()
                            Text(quote.result.suggestedPrice.map(Currency.format) ?? "Sem preço — será ignorada")
                                .monospacedDigit()
                                .foregroundStyle(CalculatorViewModel.canAddToProposal(quote) ? Theme.ink : Theme.warn)
                        }
                        .padding(.vertical, 2)
                        Divider()
                    }
                    LabeledContent("Total (1 un. de cada)", value: Currency.format(total))
                        .bold()
                        .padding(.top, 4)
                }

                HStack {
                    Button {
                        model.addQuotesToProposal(quotes, proposalID: nil)
                    } label: {
                        Label("Gerar orçamento com \(priced.count) peças", systemImage: "doc.badge.plus")
                    }
                    .buttonStyle(.primary)
                    .disabled(priced.isEmpty)
                        .pointerCursor()

                    AddToProposalMenu(quotes: quotes)
                        .fixedSize()
                }
            }
            .padding(20)
            .frame(maxWidth: 640, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg)
    }
}

private struct QuoteRow: View {
    @Environment(CalculatorViewModel.self) private var model
    let quote: QuoteRecord

    var body: some View {
        HStack(spacing: 10) {
            if let image = model.imageStore.image(for: quote.job.imageID) {
                Image(nsImage: image)
                    .resizable().aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 40)
                    .clipShape(.rect(cornerRadius: 8, style: .continuous))
            }
            details
        }
        .padding(.vertical, 4)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(quote.job.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                 ? "Peça sem nome" : quote.job.name)
                .font(.headline)
                .lineLimit(1)
            HStack {
                Text(quote.savedAt.formatted(date: .abbreviated, time: .shortened))
                Spacer()
                Text(quote.result.suggestedPrice.map(Currency.format) ?? "Preço indisponível")
                    .monospacedDigit()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

private struct QuoteDetail: View {
    @Environment(CalculatorViewModel.self) private var model
    let quote: QuoteRecord
    @Binding var nameDraft: String
    let canSaveName: Bool
    let onSaveName: () -> Void
    let useAsBase: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let image = model.imageStore.image(for: quote.job.imageID) {
                    Image(nsImage: image)
                        .resizable().aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: 220)
                        .clipShape(.rect(cornerRadius: 12, style: .continuous))
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        TextField("Nome da peça", text: $nameDraft)
                            .font(.title2.bold())
                        Button("Salvar nome", action: onSaveName)
                            .disabled(!canSaveName)
                            .pointerCursor()
                    }
                    Text("Salvo em \(quote.savedAt.formatted(date: .long, time: .shortened))")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Preço sugerido por peça").font(.subheadline).foregroundStyle(.secondary)
                    Text(quote.result.suggestedPrice.map(Currency.format) ?? "Indisponível")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.ink)
                    if case .failure(let error) = quote.result.pricing {
                        Label(error.message, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(Theme.danger)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .surface()

                GroupBox {
                    LabeledContent("Peso da mesa", value: Weight.format(grams: quote.job.partWeight))
                    LabeledContent("Tempo de impressão", value: "\(NumberMask.format(quote.result.printHours)) h")
                    LabeledContent("Peças por mesa", value: "\(quote.result.partsPerPlate)")
                    LabeledContent("Custo por peça", value: Currency.format(quote.result.unitCost))
                    LabeledContent("Custo da mesa", value: Currency.format(quote.result.plateCost))
                } label: {
                    BadgeLabel("Dados da impressão", systemImage: "cube.fill", color: .orange)
                }

                GroupBox {
                    ForEach(quote.result.items) { item in
                        LabeledContent(item.category.title, value: Currency.format(item.amount))
                    }
                    Divider()
                    LabeledContent("Total", value: Currency.format(quote.result.unitCost)).bold()
                } label: {
                    BadgeLabel("Composição do custo por peça", systemImage: "chart.pie.fill", color: .indigo)
                }

                GroupBox {
                    LabeledContent("Filamento", value: Weight.pricePerBulkUnit(perGram: quote.job.filamentPricePerGram ?? quote.settings.filamentPricePerGram))
                    LabeledContent("Hora de máquina", value: Currency.format(quote.settings.machineCostPerHour) + "/h")
                    LabeledContent("Valor da hora", value: Currency.format(quote.settings.laborRate) + "/h")
                } label: {
                    BadgeLabel("Parâmetros fixos salvos", systemImage: "gearshape.fill", color: .gray)
                }

                HStack {
                    AddToProposalMenu(quotes: [quote])
                        .fixedSize()
                    Button(action: useAsBase) {
                        Label("Usar como base", systemImage: "arrow.uturn.backward.circle.fill")
                    }
                        .pointerCursor()
                    Spacer()
                    Button(role: .destructive, action: onDelete) {
                        Label("Excluir peça", systemImage: "trash.fill")
                    }
                        .pointerCursor()
                }
            }
            .padding(20)
            .frame(maxWidth: 640, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg)
    }
}
