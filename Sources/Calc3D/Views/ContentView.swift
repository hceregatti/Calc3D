import SwiftUI

/// Janela principal: barra lateral com as telas e o conteúdo selecionado.
struct ContentView: View {
    @Environment(CalculatorViewModel.self) private var model

    var body: some View {
        @Bindable var model = model

        NavigationSplitView {
            List(selection: $model.screen) {
                ForEach(Screen.allCases) { screen in
                    NavigationLink(value: screen) {
                        HStack(alignment: .center, spacing: 12) {
                            SymbolBadge(systemImage: screen.systemImage, color: screen.color, size: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(screen.title)
                                Text(screen.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.vertical, 5)
                    }
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
