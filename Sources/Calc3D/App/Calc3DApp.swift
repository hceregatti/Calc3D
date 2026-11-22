import AppKit
import SwiftUI

@main
struct Calc3DApp: App {
    // O App é instanciado uma única vez; uma constante evita depender do macro
    // @State, cujo plugin só é distribuído com o Xcode completo.
    private let model = CalculatorViewModel()
    private let updater = UpdateChecker()

    init() {
        // Garante ícone no Dock e foco de teclado também quando executado via `swift run`.
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        Window("Calc3D", id: "main") {
            ContentView()
                .environment(model)
                .environment(updater)
                .task { await updater.check(manual: false) }
                .frame(minWidth: 1040, minHeight: 640)
        }
        .defaultSize(width: 1260, height: 820)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Verificar se há Atualizações…") { Task { await updater.check(manual: true) } }
                    .pointerCursor()
            }
            CommandGroup(replacing: .newItem) {
                Button("Nova peça") { model.newJob() }
                    .keyboardShortcut("n")
                    .pointerCursor()
                Button("Novo orçamento") { model.startNewProposal() }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                    .pointerCursor()
            }
            CommandGroup(replacing: .appSettings) {
                Button("Parâmetros fixos…") { model.screen = .settings }
                    .keyboardShortcut(",")
                    .pointerCursor()
            }
            CommandGroup(after: .pasteboard) {
                Divider()
                Button("Copiar orçamento") { model.copySummary() }
                    .keyboardShortcut("c", modifiers: [.command, .shift])
                    .pointerCursor()
            }
            CommandMenu("Ir") {
                ForEach(Array(Screen.allCases.enumerated()), id: \.element) { index, screen in
                    Button(screen.title) { model.screen = screen }
                        .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")))
                        .pointerCursor()
                }
            }
        }
    }
}
