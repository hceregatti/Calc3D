import Foundation

/// Versão semântica simples (`1.2.3`), com ou sem prefixo "v".
public struct AppVersion: Comparable, Equatable, Sendable, CustomStringConvertible {
    public let components: [Int]

    public init?(_ string: String) {
        var text = string.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("v") || text.hasPrefix("V") { text.removeFirst() }
        // Ignora sufixos de pré-lançamento/metadados (1.2.0-beta, 1.2.0+3).
        text = String(text.prefix { $0 != "-" && $0 != "+" })
        let parts = text.split(separator: ".", omittingEmptySubsequences: false).map { Int($0) }
        guard !parts.isEmpty, parts.allSatisfy({ $0 != nil }) else { return nil }
        components = parts.compactMap { $0 }
    }

    public var description: String { components.map(String.init).joined(separator: ".") }

    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let count = max(lhs.components.count, rhs.components.count)
        for i in 0..<count {
            let a = i < lhs.components.count ? lhs.components[i] : 0
            let b = i < rhs.components.count ? rhs.components[i] : 0
            if a != b { return a < b }
        }
        return false
    }

    public static func == (lhs: AppVersion, rhs: AppVersion) -> Bool {
        !(lhs < rhs) && !(rhs < lhs)
    }
}

/// Uma versão publicada no GitHub Releases.
public struct ReleaseInfo: Equatable, Sendable {
    public let version: AppVersion
    public let name: String
    public let notes: String
    public let pageURL: URL
    public let dmgURL: URL?

    public init(version: AppVersion, name: String, notes: String, pageURL: URL, dmgURL: URL?) {
        self.version = version
        self.name = name
        self.notes = notes
        self.pageURL = pageURL
        self.dmgURL = dmgURL
    }

    /// Interpreta a resposta de `GET /repos/{dono}/{repo}/releases/latest`.
    /// Retorna nil para rascunhos, pré-lançamentos ou JSON inesperado.
    public static func parse(_ data: Data) -> ReleaseInfo? {
        struct Asset: Decodable { let name: String; let browser_download_url: URL }
        struct Payload: Decodable {
            let tag_name: String
            let name: String?
            let body: String?
            let html_url: URL
            let draft: Bool?
            let prerelease: Bool?
            let assets: [Asset]?
        }
        guard let payload = try? JSONDecoder().decode(Payload.self, from: data),
              payload.draft != true, payload.prerelease != true,
              let version = AppVersion(payload.tag_name)
        else { return nil }
        let assets = payload.assets ?? []
        // Prefere o .dmg versionado; o "Calc3D.dmg" de nome fixo serve de reserva.
        let dmg = assets.first { $0.name.hasSuffix(".dmg") && $0.name != "Calc3D.dmg" }
            ?? assets.first { $0.name.hasSuffix(".dmg") }
        return ReleaseInfo(
            version: version,
            name: payload.name ?? payload.tag_name,
            notes: payload.body ?? "",
            pageURL: payload.html_url,
            dmgURL: dmg?.browser_download_url
        )
    }

    /// Monta a versão a partir do endereço para onde `github.com/<dono>/<repo>/releases/latest` redireciona
    /// (`…/releases/tag/v1.2.3`). Não depende da API do GitHub, que limita as consultas sem login.
    /// O instalador usa o `Calc3D.dmg` de nome fixo que o workflow anexa a cada release.
    public static func fromLatestRedirect(_ location: URL) -> ReleaseInfo? {
        let parts = location.pathComponents
        guard let tagIndex = parts.lastIndex(of: "tag"), tagIndex + 1 < parts.count,
              let version = AppVersion(parts[tagIndex + 1]) else { return nil }
        let tag = parts[tagIndex + 1]
        var components = URLComponents(url: location, resolvingAgainstBaseURL: false)
        components?.path = location.path.replacingOccurrences(of: "/releases/tag/", with: "/releases/download/") + "/Calc3D.dmg"
        components?.query = nil
        return ReleaseInfo(version: version, name: "Calc3D \(tag)", notes: "", pageURL: location, dmgURL: components?.url)
    }

    /// Notas em linhas simples: remove títulos/markdown e troca marcadores por "•".
    public var displayNotes: [String] {
        notes.split(whereSeparator: \.isNewline).compactMap { raw in
            var line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { return nil }
            while line.hasPrefix("#") { line.removeFirst() }
            line = line.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("* ") || line.hasPrefix("- ") { line = "• " + line.dropFirst(2) }
            return line.isEmpty ? nil : line
        }
    }
}
