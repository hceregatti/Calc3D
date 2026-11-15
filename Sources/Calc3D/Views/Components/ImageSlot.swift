import SwiftUI

/// Quadro de imagem clicável: mostra a imagem ou um marcador padrão,
/// aceita arrastar um arquivo e oferece menu para trocar ou remover.
struct ImageSlot: View {
    let image: NSImage?
    var width: CGFloat = 64
    var height: CGFloat = 64
    var placeholderSymbol = "photo"
    var placeholderText: String? = nil
    var fit: ContentMode = .fill
    let onChoose: () -> Void
    let onDropFile: (URL) -> Bool
    let onRemove: () -> Void

    // Sem o macro @State (exige o Xcode completo); State funciona como propriedade comum.
    private let targeted = State(initialValue: false)
    private var isTargeted: Bool { targeted.wrappedValue }

    var body: some View {
        Button(action: onChoose) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.quaternary.opacity(0.6))
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: fit)
                        .padding(fit == .fit ? 6 : 0)
                } else {
                    VStack(spacing: 4) {
                        Image(systemName: placeholderSymbol)
                            .font(.system(size: min(width, height) * 0.3))
                        if let placeholderText {
                            Text(placeholderText)
                                .font(.caption2)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isTargeted ? Color.accentColor : Color.secondary.opacity(0.25),
                                  lineWidth: isTargeted ? 2 : 0.5)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help(image == nil ? "Clique ou arraste uma imagem para adicionar" : "Clique para trocar a imagem")
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            return onDropFile(url)
        } isTargeted: { targeted.wrappedValue = $0 }
        .contextMenu {
            Button(image == nil ? "Escolher imagem…" : "Trocar imagem…", action: onChoose)
            if image != nil {
                Button("Remover imagem", role: .destructive, action: onRemove)
            }
        }
    }
}
