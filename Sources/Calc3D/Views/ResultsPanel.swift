import Calc3DCore
import Charts
import SwiftUI

/// Painel lateral com o preço sugerido, indicadores e composição do custo.
struct ResultsPanel: View {
    @Environment(CalculatorViewModel.self) private var model

    var body: some View {
        let r = model.result

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PriceCard(result: r)
                BreakdownCard(result: r)
                actions
            }
            .padding(20)
        }
        .background(Theme.bg)
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button {
                    model.saveQuote()
                } label: {
                    Label("Salvar peça", systemImage: "bookmark.fill")
                }
                .buttonStyle(.primary)
                    .pointerCursor()

                Button {
                    model.copySummary()
                } label: {
                    Label("Copiar", systemImage: "doc.on.doc.fill")
                }
                    .pointerCursor()
            }
            Menu {
                Button {
                    model.addCurrentCalculationToProposal(nil)
                } label: {
                    Label("Novo orçamento", systemImage: "plus.rectangle.on.rectangle")
                }

                if !model.proposals.isEmpty {
                    Section("Orçamentos existentes") {
                        ForEach(model.proposals) { proposal in
                            let title = proposal.title.trimmingCharacters(in: .whitespacesAndNewlines)
                            Button(title.isEmpty ? "Orçamento sem título" : title) {
                                model.addCurrentCalculationToProposal(proposal.id)
                            }
                        }
                    }
                }
            } label: {
                Label("Adicionar a orçamento", systemImage: "text.badge.plus")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bordered)
            .disabled(!(model.result.suggestedPrice.map { $0.isFinite && $0 >= 0 } ?? false))
            .help("Adiciona o cálculo atual a um orçamento sem salvá-lo no histórico de peças")
                .pointerCursor()

            Button("Nova peça") { model.newJob() }
                .pointerCursor()
            if let feedback = model.quoteFeedback ?? model.copyFeedback {
                Text(feedback)
                    .font(.callout)
                    .foregroundStyle(Theme.success)
                    .transition(.opacity)
            }
        }
        .animation(.default, value: model.copyFeedback)
    }
}

struct PriceCard: View {
    let result: CostResult

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Preço sugerido por peça")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(result.suggestedPrice.map(Currency.format) ?? "—")
                    .font(.system(size: 44, weight: .semibold))
                    .tracking(-1.5)
                    .foregroundStyle(Theme.accent)
                    .contentTransition(.numericText())
                if case .failure(let error) = result.pricing {
                    Label(error.message, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(Theme.danger)
                }
            }

            Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                GridRow {
                    Kpi(title: "Custo por peça", value: Currency.format(result.unitCost))
                    Kpi(title: "Lucro líquido/peça", value: result.profitPerPart.map(Currency.format) ?? "—")
                }
                GridRow {
                    Kpi(title: "Custo da mesa", value: Currency.format(result.plateCost))
                    Kpi(title: "Lucro por hora",
                        value: result.profitPerMachineHour.map { Currency.format($0) + "/h" } ?? "—")
                }
            }
        }
        .card()
    }
}

private struct Kpi: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.headline)
                .monospacedDigit()
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(height: 82)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.bg, in: .rect(cornerRadius: Theme.radiusMd, style: .continuous))
    }
}

struct BreakdownCard: View {
    let result: CostResult

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Composição do custo por peça")
                .font(.headline)

            Chart(result.items.filter { $0.amount > 0 }) { item in
                SectorMark(
                    angle: .value("Valor", item.amount),
                    innerRadius: .ratio(0.62),
                    angularInset: 1.5
                )
                .cornerRadius(3)
                .foregroundStyle(item.category.color)
            }
            .frame(height: 170)
            .overlay {
                VStack(spacing: 0) {
                    Text(Currency.format(result.unitCost))
                        .font(.title3.bold())
                        .monospacedDigit()
                    Text("por peça")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 0) {
                ForEach(result.items) { item in
                    HStack {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(item.category.color)
                            .strokeBorder(.black.opacity(0.08))
                            .frame(width: 10, height: 10)
                        Text(item.category.title)
                        Spacer()
                        Text(Currency.format(item.amount))
                            .monospacedDigit()
                        Text(result.share(of: item.category)
                            .formatted(.percent.precision(.fractionLength(1)).locale(Currency.locale)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .frame(width: 46, alignment: .trailing)
                    }
                    .padding(.vertical, 5)
                    Divider()
                }
                HStack {
                    Text("Custo total por peça").bold()
                    Spacer()
                    Text(Currency.format(result.unitCost)).bold().monospacedDigit()
                }
                .padding(.top, 8)
            }
            .font(.callout)
        }
        .card()
    }
}

