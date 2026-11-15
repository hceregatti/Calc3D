import AppKit
import ImageIO
import UniformTypeIdentifiers

/// Guarda logos e fotos de produtos em disco (Application Support), já redimensionados.
@MainActor
final class ImageStore {
    enum Kind {
        case product
        case logo

        var maxPixelSize: Int { self == .logo ? 800 : 1200 }
    }

    private let directory: URL
    private let cache = NSCache<NSUUID, NSImage>()

    init(directory: URL? = nil) {
        self.directory = directory ?? Self.defaultDirectory
        try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
    }

    static var defaultDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appending(path: "Calc3D/Images", directoryHint: .isDirectory)
    }

    /// Importa uma imagem de arquivo, reduzindo o tamanho para não pesar o app nem o PDF.
    func importImage(from url: URL, kind: Kind) -> UUID? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: kind.maxPixelSize,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }

        // Mantém PNG quando há transparência (logos); JPEG para fotos.
        let hasAlpha: Bool = switch image.alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast: false
        default: true
        }
        let type: UTType = (kind == .logo || hasAlpha) ? .png : .jpeg

        let id = UUID()
        guard let destination = CGImageDestinationCreateWithURL(
            fileURL(for: id) as CFURL, type.identifier as CFString, 1, nil
        ) else { return nil }
        let properties: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: 0.85]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        return CGImageDestinationFinalize(destination) ? id : nil
    }

    func image(for id: UUID?) -> NSImage? {
        guard let id else { return nil }
        if let cached = cache.object(forKey: id as NSUUID) { return cached }
        guard let data = try? Data(contentsOf: fileURL(for: id)), let image = NSImage(data: data) else { return nil }
        cache.setObject(image, forKey: id as NSUUID)
        return image
    }

    /// Remove arquivos que não são mais usados por nenhum orçamento nem pelo perfil.
    func prune(keeping ids: Set<UUID>) {
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        else { return }
        for file in files {
            guard let id = UUID(uuidString: file.deletingPathExtension().lastPathComponent),
                  !ids.contains(id)
            else { continue }
            try? FileManager.default.removeItem(at: file)
            cache.removeObject(forKey: id as NSUUID)
        }
    }

    /// Abre o seletor de arquivos e importa a imagem escolhida.
    func chooseImage(kind: Kind, title: String) -> UUID? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return importImage(from: url, kind: kind)
    }

    private func fileURL(for id: UUID) -> URL {
        directory.appending(path: "\(id.uuidString).img")
    }
}

extension NSColor {
    convenience init?(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let rgb = UInt32(value, radix: 16) else { return nil }
        self.init(
            srgbRed: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }

    var hexString: String {
        guard let color = usingColorSpace(.sRGB) else { return "#000000" }
        func byte(_ component: CGFloat) -> Int { Int((min(max(component, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(color.redComponent), byte(color.greenComponent), byte(color.blueComponent))
    }
}
