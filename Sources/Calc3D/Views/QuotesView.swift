import Calc3DCore
import SwiftUI

/// Histórico local de orçamentos salvos.
struct QuotesView: View {
    @Environment(CalculatorViewModel.self) private var model

    var body: some View {
        @Bindable var model = model

        VStack(spacing: 0) {
            Picker("Orçamentos", selection: $model.quotesArea) {
                ForEach(QuotesArea.allCases) { area in
                    Text(area.title).tag(area)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 440)
            .padding(12)

            if model.quotesArea == .calculations {
                calculationsContent
            } else {
                ProposalsView()
            }
        }
        .navigationTitle("Orçamentos")
        .confirmationDialog(
            "Excluir orçamento?",
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
        } message: { quoteID in
            let name = model.quotes.first(where: { $0.id == quoteID })?.job.name ?? ""
            Text("\(name.isEmpty ? "Este orçamento" : "\"\(name)\"") será removido permanentemente.")
        }
    }

    private var calculationsContent: some View {
        HStack(spacing: 0) {
            List(selection: Binding(
                get: { model.selectedQuoteID },
                set: { model.selectedQuoteID = $0 }
            )) {
                ForEach(model.quotes) { quote in
                    QuoteRow(quote: quote)
                        .tag(quote.id)
                }
            }
            .frame(minWidth: 240, idealWidth: 290, maxWidth: 340)

            Divider()

            if let quote = model.quotes.first(where: { $0.id == model.selectedQuoteID }) {
                QuoteDetail(quote: quote) {
                    model.useQuoteAsBase(quote)
                } onDelete: {
                    model.quotePendingDeletionID = quote.id
                }
            } else {
                ContentUnavailableView(
                    "Selecione um cálculo",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Os cálculos salvos aparecem nesta lista.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

private struct QuoteRow: View {
    let quote: QuoteRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(quote.job.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                 ? "Orçamento sem nome" : quote.job.name)
                .font(.headline)
                .lineLimit(1)
            HStack {
                Text(quote.savedAt.formatted(date: .abbreviated, time: .shortened))
                Spacer()
                Text(quote.result.suggestedPrice.map(Currency.brl) ?? "Preço indisponível")
                    .monospacedDigit()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct QuoteDetail: View {
    let quote: QuoteRecord
    let useAsBase: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(quote.job.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                         ? "Orçamento sem nome" : quote.job.name)
                        .font(.title2.bold())
                    Text("Salvo em \(quote.savedAt.formatted(date: .long, time: .shortened))")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Preço sugerido por peça").font(.subheadline).foregroundStyle(.secondary)
                    Text(quote.result.suggestedPrice.map(Currency.brl) ?? "Indisponível")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.tint)
                    if case .failure(let error) = quote.result.pricing {
                        Label(error.message, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(.background, in: .rect(cornerRadius: 12))

                GroupBox("Dados da impressão") {
                    LabeledContent("Peso da mesa", value: "\(quote.job.partWeight.formatted()) g")
                    LabeledContent("Tempo de impressão", value: "\(quote.result.printHours.formatted(.number.precision(.fractionLength(0...2)))) h")
                    LabeledContent("Peças por mesa", value: "\(quote.result.partsPerPlate)")
                    LabeledContent("Custo por peça", value: Currency.brl(quote.result.unitCost))
                    LabeledContent("Custo da mesa", value: Currency.brl(quote.result.plateCost))
                }

                GroupBox("Composição do custo por peça") {
                    ForEach(quote.result.items) { item in
                        LabeledContent(item.category.title, value: Currency.brl(item.amount))
                    }
                    Divider()
                    LabeledContent("Total", value: Currency.brl(quote.result.unitCost)).bold()
                }

                GroupBox("Parâmetros fixos salvos") {
                    LabeledContent("Filamento", value: Currency.brl(quote.settings.filamentPricePerGram * 1000) + "/kg")
                    LabeledContent("Hora de máquina", value: Currency.brl(quote.settings.machineCostPerHour) + "/h")
                    LabeledContent("Valor da hora", value: Currency.brl(quote.settings.laborRate) + "/h")
                }

                Button(action: useAsBase) {
                    Label("Usar como base", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(.borderedProminent)

                Button(role: .destructive, action: onDelete) {
                    Label("Excluir orçamento", systemImage: "trash")
                }
                .buttonStyle(.bordered)
            }
            .padding(20)
            .frame(maxWidth: 640, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background.secondary)
    }
}
