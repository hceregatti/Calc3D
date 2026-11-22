import AppKit
import Calc3DCore
import SwiftUI

/// Catálogo: modelos 3MF/STL já configurados, numa pasta compartilhada. O app lê as informações do arquivo
/// e calcula o custo com os parâmetros de quem está vendo.
struct CatalogView: View {
    @Environment(CalculatorViewModel.self) private var model

    var body: some View {
        Group {
            if model.isCatalogConfigured {
                CatalogBrowser()
            } else {
                CatalogSetup()
            }
        }
        .navigationTitle("Catálogo")
        .onAppear { model.refreshCatalogIfConfigured() }
    }
}

/// Primeiro uso: escolher a pasta compartilhada.
private struct CatalogSetup: View {
    @Environment(CalculatorViewModel.self) private var model

    var body: some View {
        VStack(spacing: 18) {
            ContentUnavailableView(
                "Catálogo de modelos",
                systemImage: "books.vertical",
                description: Text("Escolha a pasta compartilhada (iCloud Drive, Google Drive, Dropbox…) onde ficam os arquivos 3MF/STL já configurados. O app lê o peso e o tempo gravados em cada arquivo e calcula o custo com os seus parâmetros.")
            )
            Button("Escolher pasta…") { model.chooseCatalogFolder() }
                .buttonStyle(.borderedProminent)
            if let message = model.catalogMessage {
                Text(message).font(.caption).foregroundStyle(Theme.warn)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct CatalogBrowser: View {
    @Environment(CalculatorViewModel.self) private var model

    var body: some View {
        @Bindable var model = model
        let files = model.visibleCatalogFiles

        HStack(spacing: 0) {
            VStack(spacing: 0) {
                TextField("Buscar modelo ou pasta", text: $model.catalogSearch)
                    .textFieldStyle(.roundedBorder)
                    .padding(12)

                SelectionList(items: files, selection: $model.selectedCatalogFileID) { file in
                    CatalogFileRow(file: file)
                        .contextMenu {
                            Button("Baixar") { model.downloadCatalogFile(file) }
                            ForEach(Slicer.allCases) { slicer in
                                Button("Abrir no \(slicer.title)") { model.openCatalogFile(file, in: slicer) }
                                    .disabled(slicer.applicationURL == nil)
                            }
                            Button("Mostrar no Finder") { model.revealCatalogFile(file) }
                            Divider()
                            Button("Excluir…", role: .destructive) { model.catalogFilePendingDeletionID = file.id }
                        }
                }
                .overlay {
                    if files.isEmpty {
                        ContentUnavailableView {
                            Label(model.catalogFiles.isEmpty ? "Nenhum modelo na pasta" : "Nada encontrado", systemImage: "books.vertical")
                        } description: {
                            Text(model.catalogFiles.isEmpty
                                 ? "Coloque arquivos 3MF ou STL na pasta do catálogo e atualize."
                                 : "Ajuste a busca.")
                        }
                    }
                }

                if let message = model.catalogMessage {
                    Divider()
                    Text(message).font(.caption).foregroundStyle(Theme.warn)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(10)
                }
            }
            .frame(minWidth: 260, idealWidth: 300, maxWidth: 360)

            Divider()

            if let id = model.selectedCatalogFileID, let file = model.catalogFiles.first(where: { $0.id == id }) {
                CatalogFileDetail(file: file).id(file.id)
            } else {
                ContentUnavailableView(
                    "Selecione um modelo",
                    systemImage: "books.vertical",
                    description: Text("Veja o que o arquivo traz e o custo com os seus parâmetros.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .confirmationDialog(
            "Excluir este modelo do catálogo?",
            isPresented: Binding(
                get: { model.catalogFilePendingDeletionID != nil },
                set: { if !$0 { model.catalogFilePendingDeletionID = nil } }
            ),
            titleVisibility: .visible,
            presenting: model.catalogFiles.first { $0.id == model.catalogFilePendingDeletionID }
        ) { file in
            Button("Excluir \"\(file.name)\"", role: .destructive) { model.deleteCatalogFile(file) }
            Button("Cancelar", role: .cancel) {}
        } message: { _ in
            Text("O arquivo vai para a Lixeira e some do catálogo para todas as pessoas que usam esta pasta.")
        }
        .toolbar {
            ToolbarItemGroup {
                Button { model.uploadToCatalog() } label: {
                    Label("Enviar arquivo", systemImage: "square.and.arrow.up")
                }
                .help("Envia arquivos 3MF/STL do seu computador para a pasta do catálogo")

                Button { model.refreshCatalog() } label: {
                    Label("Atualizar", systemImage: "arrow.clockwise")
                }
                .disabled(model.isRefreshingCatalog)
                .help("Relê a pasta compartilhada")

                Menu {
                    Text(model.catalogFolderPath ?? "")
                    Button("Trocar pasta…") { model.chooseCatalogFolder() }
                    Button("Desconectar do catálogo", role: .destructive) { model.disconnectCatalog() }
                } label: {
                    Label("Pasta", systemImage: "folder")
                }
                .help("Pasta do catálogo")
            }
        }
    }
}

private struct CatalogFileRow: View {
    @Environment(CalculatorViewModel.self) private var model
    let file: CatalogFile

    var body: some View {
        HStack(spacing: 10) {
            thumbnail
            details
        }
        .padding(.vertical, 3)
        .onAppear { model.loadCatalogThumbnail(file) }
    }

    private var thumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.fill)
            if let image = model.catalogThumbnails[file.id] {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "cube").foregroundStyle(Theme.muted)
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(.rect(cornerRadius: 8, style: .continuous))
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(file.name).font(.headline).lineLimit(1)
            HStack {
                Text(file.fileExtension.uppercased())
                if !file.folder.isEmpty {
                    Text("·")
                    Text(file.folder).lineLimit(1).truncationMode(.middle)
                }
                Spacer()
                Text(file.modifiedAt.formatted(date: .abbreviated, time: .omitted))
            }
            .font(.caption).foregroundStyle(Theme.muted)
        }
    }
}

/// Cartão de um fatiador: ícone real do app, nome e estado (instalado ou não).
private struct SlicerButton: View {
    @Environment(CalculatorViewModel.self) private var model
    let slicer: Slicer
    let file: CatalogFile

    var body: some View {
        let app = slicer.applicationURL
        Button { model.openCatalogFile(file, in: slicer) } label: {
            HStack(spacing: 12) {
                icon(for: app)
                VStack(alignment: .leading, spacing: 2) {
                    Text(slicer.title).fontWeight(.semibold).foregroundStyle(Theme.ink)
                    Text(app == nil ? "Não instalado" : "Abrir cópia do modelo")
                        .font(.caption).foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 4)
                Image(systemName: "arrow.up.forward.circle.fill")
                    .font(.title3)
                    .foregroundStyle(app == nil ? Theme.muted : Theme.accent)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(SlicerCardStyle())
        .disabled(app == nil)
        .help(app == nil ? "\(slicer.title) não foi encontrado em Aplicativos" : "Abrir uma cópia do modelo no \(slicer.title)")
    }

    @ViewBuilder
    private func icon(for app: URL?) -> some View {
        if let app {
            Image(nsImage: NSWorkspace.shared.icon(forFile: app.path))
                .resizable().frame(width: 36, height: 36)
        } else {
            RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Theme.fill)
                .frame(width: 36, height: 36)
                .overlay { Image(systemName: "questionmark.app").foregroundStyle(Theme.muted) }
        }
    }
}

private struct SlicerCardStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous)
                    .fill(configuration.isPressed ? Theme.accent.opacity(0.10) : Theme.surface)
            }
            .overlay {
                RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous)
                    .strokeBorder(configuration.isPressed ? Theme.accent : Theme.border, lineWidth: configuration.isPressed ? 1.5 : 1)
            }
            .opacity(isEnabled ? 1 : 0.55)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .contentShape(.rect(cornerRadius: Theme.radiusMd))
    }
}

private struct CatalogFileDetail: View {
    @Environment(CalculatorViewModel.self) private var model
    let file: CatalogFile

    var body: some View {
        let info = model.catalogFileInfo[file.id]
        let job = model.catalogJob(for: file)

        Form {
            if let image = model.catalogThumbnails[file.id] {
                Section {
                    Image(nsImage: image)
                        .resizable().aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: 260)
                        .clipShape(.rect(cornerRadius: 12, style: .continuous))
                }
            }

            Section {
                LabeledContent("Formato", value: file.fileExtension.uppercased())
                if !file.folder.isEmpty { LabeledContent("Pasta", value: file.folder) }
                LabeledContent("Modificado em", value: file.modifiedAt.formatted(date: .long, time: .shortened))
            } header: {
                BadgeLabel(file.name, systemImage: "cube.fill", color: .cyan)
            }

            Section {
                switch info {
                case nil:
                    HStack { ProgressView().controlSize(.small); Text("Lendo o arquivo…") }
                case .failed(let message):
                    Text(message).foregroundStyle(Theme.warn)
                case .loaded(let raw):
                    if raw.plates.count > 1 {
                        Picker("Mesa", selection: Binding(
                            get: { model.catalogPlateChoice[file.id] ?? raw.plates[0].index },
                            set: { model.catalogPlateChoice[file.id] = $0 }
                        )) {
                            ForEach(raw.plates) { Text("Mesa \($0.index)").tag($0.index) }
                        }
                    }
                    let data = model.catalogData(for: file) ?? raw
                    if let printer = raw.printer {
                        if let name = printer.model ?? printer.profile {
                            LabeledContent("Impressora", value: name)
                        }
                        if let nozzle = printer.nozzleDiameter {
                            LabeledContent("Bico", value: nozzle.replacingOccurrences(of: ".", with: ",") + " mm")
                        }
                        if let layer = printer.layerHeight {
                            LabeledContent("Altura de camada", value: layer.replacingOccurrences(of: ".", with: ",") + " mm")
                        }
                        if let profile = printer.printProfile {
                            LabeledContent("Perfil de impressão", value: profile)
                        }
                    }
                    LabeledContent("Peso", value: data.weightGrams.map { Weight.format(grams: $0) } ?? "Não informado no arquivo")
                    LabeledContent("Tempo de impressão", value: data.durationSeconds.flatMap { $0 > 0 ? Self.format(seconds: $0) : nil } ?? "Não informado no arquivo")
                    if data.weightGrams == nil, let estimate = raw.estimatedWeight {
                        LabeledContent("Peso estimado") {
                            Text("≈ " + Weight.format(grams: estimate.grams)).foregroundStyle(Theme.warn)
                        }
                        Text("Calculado pelo volume do modelo (\(estimate.pieces == 1 ? "1 peça" : "\(estimate.pieces) peças")), com a densidade e o preenchimento do projeto, ou PLA a 15% se não constarem. É uma aproximação; o tempo não pode ser estimado.")
                            .font(.caption).foregroundStyle(Theme.muted)
                    }
                    if raw.plates.count > 1 {
                        Text("Arquivo com \(raw.plates.count) mesas fatiadas; escolha qual calcular.")
                            .font(.caption).foregroundStyle(Theme.muted)
                    }
                    let usedPlate = raw.plates.count > 1
                        ? raw.plates.first { $0.index == (model.catalogPlateChoice[file.id] ?? raw.plates[0].index) }
                        : raw.plates.first
                    ForEach(Array((usedPlate?.filaments ?? []).enumerated()), id: \.offset) { offset, filament in
                        LabeledContent("Filamento \(offset + 1)") {
                            Text([filament.type, filament.colorHex, Weight.format(grams: filament.grams)]
                                .compactMap { $0 }.joined(separator: " · "))
                        }
                    }
                }
            } header: {
                BadgeLabel("Informações do arquivo", systemImage: "doc.text.magnifyingglass", color: .orange)
            } footer: {
                if case .loaded(let data)? = info, model.catalogData(for: file).map({ $0.weightGrams == nil || $0.durationSeconds == nil }) ?? false {
                    Text(data.plates.count > 1 ? "Escolha uma mesa para ver o peso e o tempo."
                         : "O arquivo não traz peso e/ou tempo (precisa estar fatiado). Abra em “Calcular peça” para preencher à mão.")
                        .font(.caption).foregroundStyle(Theme.muted)
                }
            }

            if let job {
                let result = CostCalculator.calculate(settings: model.settings, job: job)
                Section {
                    LabeledContent("Custo por peça", value: Currency.format(result.unitCost))
                    LabeledContent("Preço sugerido", value: result.suggestedPrice.map(Currency.format) ?? "Indisponível").fontWeight(.semibold)
                    ForEach(result.items) { item in
                        LabeledContent(item.category.title, value: Currency.format(item.amount))
                    }
                } header: {
                    BadgeLabel("Com os seus parâmetros", systemImage: model.settings.currency.systemImage, color: .green)
                } footer: {
                    Text("Usa os parâmetros fixos, o filamento e a margem da peça que está em “Calcular peça”.")
                        .font(.caption).foregroundStyle(Theme.muted)
                }
            }

            Section {
                HStack(spacing: 12) {
                    ForEach(Slicer.allCases) { slicer in
                        SlicerButton(slicer: slicer, file: file)
                    }
                }
            } header: {
                BadgeLabel("Abrir no fatiador", systemImage: "square.and.arrow.up.on.square", color: .orange)
            } footer: {
                Text("Abre uma cópia do modelo: salvar no fatiador não altera o arquivo do catálogo.")
                    .font(.caption).foregroundStyle(Theme.muted)
            }

            Section {
                HStack {
                    Button { model.openCatalogFileInCalculator(file) } label: {
                        Label("Calcular", systemImage: "function")
                    }
                    .disabled(!isLoaded)
                    Button { model.saveCatalogFileToHistory(file) } label: {
                        Label("Salvar", systemImage: "square.and.arrow.down.fill")
                    }
                    .disabled(job == nil)
                    Button { model.downloadCatalogFile(file) } label: {
                        Label("Baixar", systemImage: "arrow.down.circle")
                    }
                    Spacer()
                }
                HStack {
                    Button { model.revealCatalogFile(file) } label: {
                        Label("Mostrar no Finder", systemImage: "folder")
                    }
                    Spacer()
                    Button(role: .destructive) { model.catalogFilePendingDeletionID = file.id } label: {
                        Label("Excluir", systemImage: "trash.fill")
                    }
                }
            }
        }
        .themedForm()
        .onAppear {
            model.loadCatalogFileInfo(file)
            model.loadCatalogThumbnail(file)
        }
    }

    private var isLoaded: Bool {
        if case .loaded? = model.catalogFileInfo[file.id] { return true }
        return false
    }

    private static func format(seconds: Double) -> String {
        let minutes = Int((seconds / 60).rounded())
        return "\(minutes / 60) h \(minutes % 60) min"
    }
}
