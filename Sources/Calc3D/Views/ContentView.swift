import SwiftUI

/// Janela principal: barra lateral com as telas e o conteúdo selecionado.
struct ContentView: View {
    @Environment(CalculatorViewModel.self) private var model

    var body: some View {
        @Bindable var model = model

        NavigationSplitView {
            List(selection: $model.screen) {
                ForEach(Screen.allCases.filter { $0 != .settings }) { screen in
                    NavigationLink(value: screen) {
                        SidebarRow(screen: screen)
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                // Parâmetros fixos ficam no rodapé da barra lateral.
                VStack(spacing: 0) {
                    Divider()
                    Button {
                        model.screen = .settings
                    } label: {
                        SidebarRow(screen: .settings, isSelected: model.screen == .settings)
                            .padding(.horizontal, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background {
                                if model.screen == .settings {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(Color.accentColor)
                                }
                            }
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                }
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
