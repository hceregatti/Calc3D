import Calc3DCore
import SwiftUI

/// Janela exibida ao buscar/encontrar atualizações.
struct UpdateSheet: View {
    @Environment(UpdateChecker.self) private var updater

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch updater.phase {
            case .idle, .checking:
                status(icon: "arrow.triangle.2.circlepath", title: "Buscando atualizações…", message: nil) {
                    ProgressView().controlSize(.small)
                }
            case .upToDate:
                status(icon: "checkmark.circle", title: "Você está atualizado",
                       message: "O Calc3D \(updater.currentVersion.description) é a versão mais recente.") {
                    Button("OK") { updater.dismiss() }
                        .buttonStyle(.primary).keyboardShortcut(.defaultAction)
                        .pointerCursor()
                }
            case .failed(let message):
                status(icon: "exclamationmark.triangle", title: "Algo deu errado", message: message) {
                    Button("Fechar") { updater.dismiss() }
                        .buttonStyle(.primary).keyboardShortcut(.defaultAction)
                        .pointerCursor()
                }
            case .available(let release):
                available(release, downloading: false)
            case .downloading(let release):
                available(release, downloading: true)
            }
        }
        .padding(24)
        .frame(width: 460)
        .background(Theme.bg)
    }

    private func status<Actions: View>(icon: String, title: String, message: String?,
                                       @ViewBuilder actions: () -> Actions) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 32, weight: .light)).foregroundStyle(Theme.ink2)
            Text(title).font(.title3.weight(.semibold)).foregroundStyle(Theme.ink)
            if let message {
                Text(message).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
            }
            actions().padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func available(_ release: ReleaseInfo, downloading: Bool) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Nova versão disponível").font(.title3.weight(.semibold)).foregroundStyle(Theme.ink)
                Text("Calc3D \(release.version.description) está disponível — você tem a \(updater.currentVersion.description).")
                    .foregroundStyle(Theme.muted)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("O QUE MUDOU").font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        let lines = release.displayNotes
                        if lines.isEmpty {
                            Text("Sem notas para esta versão.").foregroundStyle(Theme.muted)
                        }
                        ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                            Text(LocalizedStringKey(line)).foregroundStyle(Theme.ink2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(12)
                }
                .frame(height: 170)
                .surface(cornerRadius: Theme.radiusMd)
            }

            HStack {
                Button("Pular esta versão") { updater.skip(release) }
                    .buttonStyle(.subtleLink)
                    .pointerCursor()
                Spacer()
                if downloading {
                    ProgressView().controlSize(.small)
                    Text("Atualizando…").foregroundStyle(Theme.muted)
                } else {
                    Button("Mais tarde") { updater.remindLater() }
                        .keyboardShortcut(.cancelAction)
                        .pointerCursor()
                    Button("Atualizar agora") { Task { await updater.install(release) } }
                        .buttonStyle(.primary).keyboardShortcut(.defaultAction)
                        .pointerCursor()
                }
            }
            .disabled(downloading)
        }
    }
}
