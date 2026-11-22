import Calc3DCore
import SwiftUI

/// Tela inicial: atalhos, números gerais e itens recentes.
struct HomeView: View {
    @Environment(CalculatorViewModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                quickActions
                stats
                HStack(alignment: .top, spacing: 16) {
                    recentParts
                    recentProposals
                }
            }
            .padding(28)
            .frame(maxWidth: 1000, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.bg)
        .navigationTitle("Início")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Calc3D")
                .font(.largeTitle.bold())
            Text("Calcule peças, guarde no histórico e monte orçamentos com várias peças.")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    private var quickActions: some View {
        Grid(horizontalSpacing: 14, verticalSpacing: 14) {
            GridRow {
                ActionCard(
                    title: "Calcular peça",
                    subtitle: "Novo cálculo a partir do fatiador",
                    systemImage: Screen.printJob.systemImage,
                    color: Screen.printJob.color,
                    prominent: true
                ) { model.newJob() }
                ActionCard(
                    title: "Novo orçamento",
                    subtitle: "Junte várias peças do histórico",
                    systemImage: "doc.badge.plus",
                    color: Screen.proposals.color
                ) { model.startNewProposal() }
                ActionCard(
                    title: "Peças",
                    subtitle: "Histórico de cálculos salvos",
                    systemImage: Screen.parts.systemImage,
                    color: Screen.parts.color
                ) { model.screen = .parts }
                ActionCard(
                    title: "Parâmetros",
                    subtitle: "Filamento, máquina e taxas",
                    systemImage: Screen.settings.systemImage,
                    color: Screen.settings.color
                ) { model.screen = .settings }
            }
        }
    }

    private var stats: some View {
        let waiting = model.proposals(in: .waiting)
        let waitingTotal = model.proposalsTotal(in: .waiting)
        return HStack(spacing: 14) {
            StatTile(value: "\(model.quotes.count)", title: "Peças no histórico", systemImage: Screen.parts.systemImage, color: Screen.parts.color)
            StatTile(value: "\(model.proposals.count)", title: "Orçamentos", systemImage: Screen.proposals.systemImage, color: Screen.proposals.color)
            StatTile(value: Currency.format(waitingTotal), title: "Aguardando aprovação (\(waiting.count))", systemImage: "banknote.fill", color: .teal)
            StatTile(
                value: model.result.suggestedPrice.map(Currency.format) ?? "—",
                title: model.job.name.isEmpty ? "Cálculo em andamento" : "Em andamento: \(model.job.name)",
                systemImage: "pencil.and.ruler.fill",
                color: Screen.printJob.color
            )
        }
    }

    private var recentParts: some View {
        RecentSection(
            title: "Peças recentes",
            emptyText: "Nenhuma peça salva ainda.",
            isEmpty: model.quotes.isEmpty,
            seeAll: { model.screen = .parts }
        ) {
            ForEach(model.quotes.prefix(5)) { quote in
                RecentRow(
                    title: quote.job.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? "Peça sem nome" : quote.job.name,
                    detail: quote.savedAt.formatted(date: .abbreviated, time: .shortened),
                    value: quote.result.suggestedPrice.map(Currency.format) ?? "—",
                    systemImage: "cube.fill",
                    color: Screen.parts.color
                ) { model.showPart(quote.id) }
            }
        }
    }

    private var recentProposals: some View {
        RecentSection(
            title: "Orçamentos recentes",
            emptyText: "Nenhum orçamento criado ainda.",
            isEmpty: model.proposals.isEmpty,
            seeAll: { model.screen = .proposals }
        ) {
            ForEach(model.proposals.prefix(5)) { proposal in
                let title = proposal.title.trimmingCharacters(in: .whitespacesAndNewlines)
                RecentRow(
                    title: title.isEmpty ? "Orçamento sem título" : title,
                    detail: "\(proposal.items.count) \(proposal.items.count == 1 ? "item" : "itens")"
                        + (proposal.customerName.isEmpty ? "" : " · \(proposal.customerName)"),
                    value: proposal.total.map(Currency.format) ?? "—",
                    systemImage: "doc.text.fill",
                    color: Screen.proposals.color
                ) { model.showProposal(proposal.id) }
            }
        }
    }
}

private struct ActionCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let color: Color
    var prominent = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                if prominent {
                    Image(systemName: systemImage)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(Theme.onAccent)
                        .frame(width: 36, height: 36)
                        .background(Theme.onAccent.opacity(0.16), in: .rect(cornerRadius: Theme.radiusMd, style: .continuous))
                } else {
                    SymbolBadge(systemImage: systemImage, color: color, size: 36, iconColor: Theme.accent)
                }
                Spacer(minLength: 0)
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(prominent ? AnyShapeStyle(Theme.onAccent.opacity(0.8)) : AnyShapeStyle(.secondary))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(prominent ? AnyShapeStyle(Theme.onAccent) : AnyShapeStyle(Theme.ink))
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 130, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous)
                    .fill(prominent ? Theme.accent : Theme.surface)
            }
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous)
                .strokeBorder(prominent ? Theme.accent : Theme.border))
            .contentShape(.rect(cornerRadius: Theme.radiusLg))
        }
        .buttonStyle(CardPressStyle())
            .pointerCursor()
    }
}

private struct CardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct StatTile: View {
    let value: String
    let title: String
    let systemImage: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SymbolBadge(systemImage: systemImage, color: color, size: 24, iconColor: Theme.accent)
            Text(value)
                .font(.title2.bold())
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surface()
    }
}

private struct RecentSection<Content: View>: View {
    let title: String
    let emptyText: String
    let isEmpty: Bool
    let seeAll: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                Button("Ver todos", action: seeAll)
                    .buttonStyle(.subtleLink)
                    .disabled(isEmpty)
                    .pointerCursor()
            }
            if isEmpty {
                Text(emptyText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                VStack(spacing: 0) { content }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .surface()
    }
}

private struct RecentRow: View {
    let title: String
    let detail: String
    let value: String
    let systemImage: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                SymbolBadge(systemImage: systemImage, color: color, size: 26)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).lineLimit(1)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(value)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.forward")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 7)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
            .pointerCursor()
    }
}
