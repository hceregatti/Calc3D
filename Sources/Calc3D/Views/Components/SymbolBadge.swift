import SwiftUI

/// Ícone moderno: SF Symbol preenchido sobre um quadrado arredondado com gradiente,
/// no estilo dos Ajustes do Sistema do macOS.
struct SymbolBadge: View {
    let systemImage: String
    let color: Color
    var size: CGFloat = 22

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
            .fill(color.gradient)
            .overlay {
                Image(systemName: systemImage)
                    .symbolRenderingMode(.monochrome)
                    .font(.system(size: size * 0.55, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: size, height: size)
            .shadow(color: color.opacity(0.25), radius: size * 0.08, y: size * 0.04)
            .accessibilityHidden(true)
    }
}

/// Título de seção com ícone em badge.
struct BadgeLabel: View {
    let title: String
    let systemImage: String
    let color: Color

    init(_ title: String, systemImage: String, color: Color) {
        self.title = title
        self.systemImage = systemImage
        self.color = color
    }

    var body: some View {
        Label {
            Text(title)
        } icon: {
            SymbolBadge(systemImage: systemImage, color: color, size: 18)
        }
    }
}
