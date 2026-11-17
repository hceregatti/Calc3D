import SwiftUI

/// Janela principal: barra lateral com as telas e o conteúdo selecionado.
struct ContentView: View {
    @Environment(CalculatorViewModel.self) private var model
    @Environment(UpdateChecker.self) private var updater

    var body: some View {
        @Bindable var model = model

        NavigationSplitView {
            List {
                ForEach(Screen.allCases.filter { !Screen.footerScreens.contains($0) }) { screen in
                    SidebarButton(screen: screen, isSelected: model.screen == screen) {
                        model.screen = screen
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                // Configurações ficam no rodapé da barra lateral.
                VStack(spacing: 2) {
                    Divider()
                        .overlay(Theme.border)
                        .padding(.bottom, 6)
                    ForEach(Screen.footerScreens) { screen in
                        SidebarButton(screen: screen, isSelected: model.screen == screen) {
                            model.screen = screen
                        }
                        .padding(.horizontal, 10)
                    }
                }
                .padding(.bottom, 8)
            }
            .background(Theme.bg)
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
        .tint(Theme.ink)
        .sheet(isPresented: Binding(
            get: { updater.isPresented },
            set: { if !$0 { updater.dismiss() } }
        )) {
            UpdateSheet()
        }
        .toolbarBackground(Theme.bg, for: .windowToolbar)
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

/// Item da barra lateral com o destaque neutro do design system
/// (fundo cinza claro e texto em negrito em vez do azul do sistema).
private struct SidebarButton: View {
    let screen: Screen
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                SymbolBadge(systemImage: screen.systemImage, color: screen.color, size: 28,
                            fill: isSelected ? Theme.surface : Theme.fill)
                VStack(alignment: .leading, spacing: 2) {
                    Text(screen.title)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundStyle(isSelected ? Theme.ink : Theme.ink2)
                    Text(screen.subtitle)
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous)
                    .fill(isSelected ? Theme.active : .clear)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
