import AppKit
import Calc3DCore
import Observation

/// Busca novas versões no GitHub Releases e instala a atualização no lugar do app.
@MainActor
@Observable
final class UpdateChecker {
    enum Phase: Equatable {
        case idle
        case checking
        case upToDate
        case available(ReleaseInfo)
        case downloading(ReleaseInfo)
        case failed(String)
    }

    static let latestReleaseURL = URL(string: "https://api.github.com/repos/hceregatti/Calc3D/releases/latest")!
    private static let skippedKey = "update.skippedVersion"

    var phase: Phase = .idle
    /// Controla a exibição da janela de atualização.
    var isPresented = false

    let currentVersion: AppVersion = AppVersion(
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    ) ?? AppVersion("0")!

    private var skippedVersion: AppVersion? {
        UserDefaults.standard.string(forKey: Self.skippedKey).flatMap(AppVersion.init)
    }

    /// `manual`: ação do menu — ignora "pular versão" e informa quando não há novidade.
    func check(manual: Bool) async {
        if case .checking = phase { return }
        if case .downloading = phase { return }
        if manual {
            phase = .checking
            isPresented = true
        }
        do {
            var request = URLRequest(url: Self.latestReleaseURL, timeoutInterval: 15)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let release = ReleaseInfo.parse(data)
            else { throw UpdateError.badResponse }

            guard release.version > currentVersion else {
                if manual { phase = .upToDate }
                return
            }
            if !manual, let skipped = skippedVersion, release.version <= skipped { return }
            phase = .available(release)
            isPresented = true
        } catch {
            // Falhas na checagem automática são silenciosas (ex.: sem internet).
            if manual { phase = .failed("Não foi possível buscar atualizações. Verifique sua conexão e tente novamente.") }
        }
    }

    /// "Mais tarde": fecha e volta a avisar na próxima abertura do app.
    func remindLater() { dismiss() }

    func skip(_ release: ReleaseInfo) {
        UserDefaults.standard.set(release.version.description, forKey: Self.skippedKey)
        dismiss()
    }

    func dismiss() {
        isPresented = false
        phase = .idle
    }

    func openReleasePage(_ release: ReleaseInfo) {
        NSWorkspace.shared.open(release.pageURL)
    }

    /// Baixa o .dmg, troca o app em execução e reabre a nova versão.
    func install(_ release: ReleaseInfo) async {
        let target = Bundle.main.bundleURL
        guard let dmgURL = release.dmgURL,
              target.pathExtension == "app",
              FileManager.default.isWritableFile(atPath: target.deletingLastPathComponent().path)
        else {
            // Execução fora de um .app (ex.: swift run) ou sem permissão de escrita: instalação manual.
            openReleasePage(release)
            dismiss()
            return
        }
        phase = .downloading(release)
        do {
            let (tmpDMG, _) = try await URLSession.shared.download(from: dmgURL)
            let staging = FileManager.default.temporaryDirectory
                .appendingPathComponent("calc3d-update-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
            let dmg = staging.appendingPathComponent("update.dmg")
            try FileManager.default.moveItem(at: tmpDMG, to: dmg)

            let newApp = try await Task.detached { try Self.extractApp(dmg: dmg, staging: staging) }.value
            try Self.launchReplacement(newApp: newApp, target: target)
            quit()
        } catch {
            phase = .failed("A atualização falhou. Você pode baixar a versão manualmente na página de releases.")
        }
    }

    /// Encerra o app para o script trocar o bundle. Fecha a janela de atualização antes e,
    /// como `terminate` pode ser adiado ou cancelado, força a saída se o app ainda estiver aberto.
    private func quit() {
        isPresented = false
        NSApp.terminate(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { exit(0) }
    }

    // MARK: - Instalação

    private nonisolated static func extractApp(dmg: URL, staging: URL) throws -> URL {
        let mount = staging.appendingPathComponent("mnt")
        try FileManager.default.createDirectory(at: mount, withIntermediateDirectories: true)
        try run("/usr/bin/hdiutil", ["attach", dmg.path, "-nobrowse", "-readonly", "-noverify", "-mountpoint", mount.path])
        defer { _ = try? run("/usr/bin/hdiutil", ["detach", mount.path, "-force"]) }
        let apps = try FileManager.default.contentsOfDirectory(at: mount, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "app" }
        guard let app = apps.first else { throw UpdateError.badResponse }
        let copy = staging.appendingPathComponent("Calc3D.app")
        try run("/usr/bin/ditto", [app.path, copy.path])
        return copy
    }

    /// Script desacoplado: espera o app encerrar, troca o bundle e reabre.
    private static func launchReplacement(newApp: URL, target: URL) throws {
        let script = """
        while kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; do sleep 0.2; done
        rm -rf "$2" && /usr/bin/ditto "$1" "$2" && /usr/bin/xattr -dr com.apple.quarantine "$2" 2>/dev/null
        /usr/bin/open "$2"
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script, "sh", newApp.path, target.path]
        try process.run()
    }

    @discardableResult
    private nonisolated static func run(_ path: String, _ args: [String]) throws -> Int32 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try p.run()
        p.waitUntilExit()
        guard p.terminationStatus == 0 else { throw UpdateError.badResponse }
        return p.terminationStatus
    }

    private enum UpdateError: Error { case badResponse }
}
