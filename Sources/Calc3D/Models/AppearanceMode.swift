import SwiftUI

/// Aparência do app: acompanha o sistema ou força o modo claro/escuro.
enum AppearanceMode: String, CaseIterable, Identifiable {
    static let defaultsKey = "calc3d.appearance"

    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "Automático"
        case .light: "Claro"
        case .dark: "Escuro"
        }
    }

    var systemImage: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }

    /// nil deixa o sistema decidir.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
