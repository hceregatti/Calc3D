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
                        Label {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(screen.title)
                                Text(screen.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: screen.systemImage)
                        }
                        .padding(.vertical, 3)
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 230, max: 280)
        } detail: {
            switch model.screen ?? .printJob {
            case .printJob:
                PrintJobView()
            case .quotes:
                QuotesView()
            case .settings:
                ShopSettingsView()
            }
        }
    }
}
