import AppKit
import SwiftUI

/// Cursor de mãozinha (pointer) ao passar o mouse sobre um controle clicável.
private struct PointerCursorModifier: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled

    func body(content: Content) -> some View {
        if #available(macOS 15.0, *) {
            content.pointerStyle(isEnabled ? .link : nil)
        } else {
            content.onHover { inside in
                guard isEnabled else { return }
                if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
        }
    }
}

extension View {
    /// Mostra o cursor de mãozinha sobre este controle (botões, menus e itens clicáveis).
    func pointerCursor() -> some View { modifier(PointerCursorModifier()) }
}
