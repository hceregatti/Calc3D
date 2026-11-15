import SwiftUI

/// Janela principal: barra lateral com as telas e o conteúdo selecionado.
struct ContentView: View {
    @Environment(CalculatorViewModel.self) private var model

    var body: some View {
        @Bindable var model = model

        NavigationSplitView {
            List(selection: $model.screen) {
                ForEach(Screen.allCases.filter { !Screen.footerScreens.contains($0) }) { screen in
                    NavigationLink(value: screen) {
                        SidebarRow(screen: screen)
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                // Configurações ficam no rodapé da barra lateral.
                VStack(spacing: 2) {
                    Divider()
                        .padding(.bottom, 6)
                    ForEach(Screen.footerScreens) { screen in
                        Button {
                            model.screen = screen
                        } label: {
                            SidebarRow(screen: screen, isSelected: model.screen == screen)
                                .padding(.horizontal, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background {
                                    if model.screen == screen {
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .fill(Color.accentColor)
                                    }
                                }
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 10)
                    }
                }
                .padding(.bottom, 8)
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 230, max: 280)
        } detail: {
            switch model.screen ?? .home {
            case .home:
                HomeView()
            case .printJob:
                PrintJobView()
            case .parts:
                PartsView()
            case .proposals:
                ProposalsView()
            case .settings:
                ShopSettingsView()
            case .company:
                CompanySettingsView()
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
            Text("As alterações não salvas neste orçamento serão perdidas.")
        }
    }
}

extension Screen {
    /// Telas de configuração exibidas no rodapé da barra lateral.
    static let footerScreens: [Screen] = [.company, .settings]
}

/// Linha da barra lateral: ícone centralizado com título e subtítulo.
private struct SidebarRow: View {
    let screen: Screen
    /// Usado na linha do rodapé, que desenha o próprio destaque de seleção.
    var isSelected = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            SymbolBadge(systemImage: screen.systemImage, color: screen.color, size: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(screen.title)
                    .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                Text(screen.subtitle)
                    .font(.caption)
                    .foregroundStyle(isSelected ? AnyShapeStyle(.white.opacity(0.85)) : AnyShapeStyle(.secondary))
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 5)
    }
}
