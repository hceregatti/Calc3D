import AppKit
import SwiftUI

@main
struct Calc3DApp: App {
    // O App é instanciado uma única vez; uma constante evita depender do macro
    // @State, cujo plugin só é distribuído com o Xcode completo.
    private let model = CalculatorViewModel()

    init() {
        // Garante ícone no Dock e foco de teclado também quando executado via `swift run`.
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        Window("Calculadora de Impressão 3D", id: "main") {
            ContentView()
                .environment(model)
                .frame(minWidth: 1040, minHeight: 640)
        }
        .defaultSize(width: 1260, height: 820)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Nova peça") { model.newJob() }
                    .keyboardShortcut("n")
                Button("Novo orçamento") { model.startNewProposal() }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
            }
            CommandGroup(replacing: .appSettings) {
                Button("Parâmetros fixos…") { model.screen = .settings }
                    .keyboardShortcut(",")
            }
            CommandGroup(after: .pasteboard) {
                Divider()
                Button("Copiar orçamento") { model.copySummary() }
                    .keyboardShortcut("c", modifiers: [.command, .shift])
            }
            CommandMenu("Ir") {
                ForEach(Array(Screen.allCases.enumerated()), id: \.element) { index, screen in
                    Button(screen.title) { model.screen = screen }
                        .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")))
                }
            }
        }
    }
}
