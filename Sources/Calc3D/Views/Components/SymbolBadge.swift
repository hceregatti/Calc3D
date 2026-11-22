import SwiftUI

/// Ícone em selo: SF Symbol sobre um quadrado arredondado neutro (design system).
struct SymbolBadge: View {
    let systemImage: String
    /// Cor de identificação da tela/seção. O design system neutro não a usa no selo;
    /// fica aqui para manter as chamadas e facilitar voltar a um visual colorido.
    let color: Color
    var size: CGFloat = 22
    var fill: Color = Theme.fill
    /// Cor do ícone; nil usa a tinta secundária neutra.
    var iconColor: Color? = nil

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
            .fill(fill)
            .overlay {
                Image(systemName: systemImage)
                    .symbolRenderingMode(.monochrome)
                    .font(.system(size: size * 0.55, weight: .semibold))
                    .foregroundStyle(iconColor ?? Theme.ink2)
            }
            .frame(width: size, height: size)
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
        HStack(alignment: .center, spacing: 8) {
            SymbolBadge(systemImage: systemImage, color: color, size: 20)
            Text(title)
        }
    }
}
