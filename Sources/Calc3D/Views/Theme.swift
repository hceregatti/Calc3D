import AppKit
import SwiftUI

/// Tokens do design system Calc3D (neutro / minimalista), os mesmos da versão web
/// em `web/src/design-system.css`. Cada cor tem variante clara e escura.
enum Theme {
    // Paleta base
    static let ink = adaptive(light: 0x1C1C1A, dark: 0xF2F1EE)
    static let ink2 = adaptive(light: 0x3A3A37, dark: 0xD6D5D0)
    static let muted = adaptive(light: 0x6B6A66, dark: 0x9D9C97)
    static let border = adaptive(light: 0xE7E6E2, dark: 0x34342F)
    static let divider = adaptive(light: 0xEFEEEB, dark: 0x2B2B27)
    static let fill = adaptive(light: 0xEFEEEB, dark: 0x2B2B27)
    static let active = adaptive(light: 0xE9E8E4, dark: 0x34342F)
    static let bg = adaptive(light: 0xF6F6F4, dark: 0x161614)
    static let surface = adaptive(light: 0xFFFFFF, dark: 0x1F1F1C)

    // Cor de destaque (terracota) e o texto sobre ela
    static let accent = adaptive(light: 0xC2410C, dark: 0xF2784B)
    static let onAccent = adaptive(light: 0xFFFFFF, dark: 0x161614)

    // Estados (discretos)
    static let danger = adaptive(light: 0x8A2B22, dark: 0xE8867C)
    static let warn = adaptive(light: 0x8A5A12, dark: 0xE0B067)
    static let success = adaptive(light: 0x2F5D3A, dark: 0x8FC39B)

    /// Cores categóricas dos gráficos, distintas entre si (uma por categoria de custo).
    static let chart: [Color] = [
        adaptive(light: 0x2F6FDB, dark: 0x6EA4F5),
        adaptive(light: 0x38A6E8, dark: 0x7CC4F2),
        adaptive(light: 0x1A9E8F, dark: 0x4FC7B8),
        adaptive(light: 0x7A4FD1, dark: 0xA98AF0),
        adaptive(light: 0xC9A21A, dark: 0xE5C75A),
        adaptive(light: 0xD6403A, dark: 0xF0766F),
        adaptive(light: 0x3F9E3F, dark: 0x7FCF7F),
        adaptive(light: 0xD1479B, dark: 0xEE86C4),
    ]

    // Raios
    static let radiusSm: CGFloat = 8
    static let radiusMd: CGFloat = 10
    static let radiusLg: CGFloat = 16

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return rgb(isDark ? dark : light)
        })
    }

    private static func rgb(_ hex: UInt32) -> NSColor {
        NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1)
    }
}

/// Botão primário do design system: fundo na cor de destaque, texto legível sobre ela.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .foregroundStyle(Theme.onAccent)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Theme.accent.opacity(configuration.isPressed ? 0.85 : 1),
                        in: .rect(cornerRadius: Theme.radiusMd, style: .continuous))
            .opacity(isEnabled ? 1 : 0.45)
            .contentShape(.rect(cornerRadius: Theme.radiusMd))
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

/// Link discreto: texto em tinta secundária com sublinhado sutil.
struct SubtleLinkButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fontWeight(.medium)
            .foregroundStyle(configuration.isPressed ? Theme.accent : Theme.ink2)
            .underline(color: Theme.border)
            .opacity(isEnabled ? 1 : 0.4)
            .contentShape(.rect)
    }
}

extension ButtonStyle where Self == SubtleLinkButtonStyle {
    static var subtleLink: SubtleLinkButtonStyle { SubtleLinkButtonStyle() }
}

extension View {
    /// Cartão do design system: superfície branca, borda fina, sem sombra.
    func card() -> some View {
        padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .surface()
    }

    /// Fundo e borda de cartão, sem padding.
    func surface(cornerRadius: CGFloat = Theme.radiusLg) -> some View {
        background(Theme.surface, in: .rect(cornerRadius: cornerRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).strokeBorder(Theme.border))
    }

    /// Formulário agrupado sobre o fundo do app.
    func themedForm() -> some View {
        formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
    }
}
