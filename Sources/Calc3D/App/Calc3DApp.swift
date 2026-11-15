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
                .frame(minWidth: 960, minHeight: 640)
        }
        .defaultSize(width: 1180, height: 820)
        .commands {
            CommandGroup(after: .pasteboard) {
                Divider()
                Button("Copiar orçamento") { model.copySummary() }
                    .keyboardShortcut("c", modifiers: [.command, .shift])
            }
            CommandGroup(after: .newItem) {
                Button("Restaurar valores padrão") { model.reset() }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
            }
        }
    }
}
