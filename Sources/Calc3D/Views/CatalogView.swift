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

                List(selection: $model.selectedCatalogFileID) {
                    ForEach(files) { file in
                        CatalogFileRow(file: file).tag(Optional(file.id))
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
    let file: CatalogFile

    var body: some View {
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
        .padding(.vertical, 3)
    }
}

private struct CatalogFileDetail: View {
    @Environment(CalculatorViewModel.self) private var model
    let file: CatalogFile

    var body: some View {
        let info = model.catalogFileInfo[file.id]
        let job = model.catalogJob(for: file)

        Form {
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
                HStack {
                    Button { model.openCatalogFileInCalculator(file) } label: {
                        Label("Abrir em Calcular peça", systemImage: "function")
                    }
                    .disabled(!isLoaded)
                    Button { model.saveCatalogFileToHistory(file) } label: {
                        Label("Salvar no meu histórico", systemImage: "square.and.arrow.down.fill")
                    }
                    .disabled(job == nil)
                    Button { model.downloadCatalogFile(file) } label: {
                        Label("Baixar para o computador", systemImage: "arrow.down.circle")
                    }
                    Spacer()
                    Button { model.revealCatalogFile(file) } label: {
                        Label("Mostrar no Finder", systemImage: "folder")
                    }
                }
            }
        }
        .themedForm()
        .onAppear { model.loadCatalogFileInfo(file) }
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
