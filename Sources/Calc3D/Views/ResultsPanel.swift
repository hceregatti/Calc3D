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
        .background(.background.secondary)
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button {
                    model.saveQuote()
                } label: {
                    Label("Salvar orçamento", systemImage: "bookmark")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    model.copySummary()
                } label: {
                    Label("Copiar", systemImage: "doc.on.doc")
                }
            }
            Button("Nova impressão") { model.newJob() }
            if let feedback = model.quoteFeedback ?? model.copyFeedback {
                Text(feedback)
                    .font(.callout)
                    .foregroundStyle(.green)
                    .transition(.opacity)
            }
        }
        .animation(.default, value: model.copyFeedback)
    }
}

private struct PriceCard: View {
    let result: CostResult

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Preço sugerido por peça")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(result.suggestedPrice.map(Currency.brl) ?? "—")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.tint)
                    .contentTransition(.numericText())
                if case .failure(let error) = result.pricing {
                    Label(error.message, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.red)
                }
            }

            Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                GridRow {
                    Kpi(title: "Custo por peça", value: Currency.brl(result.unitCost))
                    Kpi(title: "Lucro líquido/peça", value: result.profitPerPart.map(Currency.brl) ?? "—")
                }
                GridRow {
                    Kpi(title: "Custo da mesa", value: Currency.brl(result.plateCost))
                    Kpi(title: "Lucro por hora",
                        value: result.profitPerMachineHour.map { Currency.brl($0) + "/h" } ?? "—")
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
        .frame(maxWidth: .infinity, height: 82, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 8))
    }
}

private struct BreakdownCard: View {
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
                    Text(Currency.brl(result.unitCost))
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
                        Circle()
                            .fill(item.category.color)
                            .frame(width: 9, height: 9)
                        Text(item.category.title)
                        Spacer()
                        Text(Currency.brl(item.amount))
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
                    Text(Currency.brl(result.unitCost)).bold().monospacedDigit()
                }
                .padding(.top, 8)
            }
            .font(.callout)
        }
        .card()
    }
}

private extension View {
    func card() -> some View {
        padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background, in: .rect(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.separator))
    }
}
