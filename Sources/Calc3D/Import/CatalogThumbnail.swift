import AppKit
import QuickLookThumbnailing

/// Imagem de pré-visualização de um modelo do catálogo.
enum CatalogThumbnail {
    /// Imagens que o fatiador/site grava dentro do 3MF, da mais bonita (capa) para a mais técnica.
    private static let embeddedCandidates = [
        "Auxiliaries/.thumbnails/thumbnail_middle.png",
        "Auxiliaries/.thumbnails/thumbnail_3mf.png",
        "Metadata/thumbnail.png",
        "Thumbnails/thumbnail.png",
        "Metadata/plate_1.png",
        "Metadata/top_1.png",
    ]
    private static let maxImageBytes = 12 * 1024 * 1024

    /// Bytes da imagem embutida no 3MF (nil se não houver). Roda fora da thread principal.
    static func embeddedImageData(in url: URL) -> Data? {
        guard url.pathExtension.lowercased() == "3mf",
              let entries = try? ModelFileImporter.archiveEntries(at: url) else { return nil }
        for candidate in embeddedCandidates {
            guard let path = entries.first(where: { $0.caseInsensitiveCompare(candidate) == .orderedSame }),
                  let data = try? ModelFileImporter.runUnzip(["-p", url.path, path], maxBytes: maxImageBytes),
                  NSImage(data: data) != nil else { continue }
            return data
        }
        return nil
    }

    /// Miniatura gerada pelo Quick Look (funciona para STL e 3MF sem imagem embutida).
    /// Usa a versão com callback e devolve só os bytes da imagem: `QLThumbnailRepresentation` não é
    /// `Sendable`, e o compilador do macOS 15 recusa passá-lo entre contextos de concorrência.
    @MainActor
    static func quickLookImage(for url: URL) async -> NSImage? {
        let request = QLThumbnailGenerator.Request(
            fileAt: url, size: CGSize(width: 512, height: 512),
            scale: NSScreen.main?.backingScaleFactor ?? 2, representationTypes: .thumbnail
        )
        let png: Data? = await withCheckedContinuation { (continuation: CheckedContinuation<Data?, Never>) in
            // `@Sendable` explícito: o Quick Look chama o callback numa thread de fundo e o fechamento
            // não pode herdar o isolamento da thread principal.
            let completion: @Sendable (QLThumbnailRepresentation?, (any Error)?) -> Void = { representation, _ in
                let data = representation.flatMap {
                    NSBitmapImageRep(cgImage: $0.cgImage).representation(using: .png, properties: [:])
                }
                continuation.resume(returning: data)
            }
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request, completion: completion)
        }
        return png.flatMap { NSImage(data: $0) }
    }
}
