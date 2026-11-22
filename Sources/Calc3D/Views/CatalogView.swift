import Calc3DCore
import SwiftUI

/// Catálogo compartilhado: peças publicadas por mim e por outras pessoas na pasta em comum.
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

/// Primeiro uso: escolher a pasta compartilhada e informar o nome.
private struct CatalogSetup: View {
    @Environment(CalculatorViewModel.self) private var model

    var body: some View {
        @Bindable var model = model

        VStack(spacing: 18) {
            ContentUnavailableView(
                "Catálogo compartilhado",
                systemImage: "books.vertical",
                description: Text("Publique peças calculadas numa pasta em comum (iCloud Drive, Google Drive, Dropbox…) para outras pessoas verem e reaproveitarem, com os parâmetros que você usou.")
            )
            Form {
                Section {
                    TextField("Seu nome no catálogo", text: $model.catalogUserName, prompt: Text("Ex.: Ana"))
                    LabeledContent("Pasta compartilhada") {
                        HStack {
                            Text(model.catalogFolderPath ?? "Nenhuma")
                                .foregroundStyle(Theme.muted).lineLimit(1).truncationMode(.middle)
                            Button("Escolher…") { model.chooseCatalogFolder() }
                        }
                    }
                } footer: {
                    Text("Cada pessoa escolhe a mesma pasta sincronizada no próprio Mac. Só quem publica uma peça pode alterá-la ou removê-la.")
                        .font(.caption).foregroundStyle(Theme.muted)
                }
                if let message = model.catalogMessage {
                    Text(message).font(.caption).foregroundStyle(Theme.warn)
                }
            }
            .themedForm()
            .frame(maxWidth: 520, maxHeight: 220)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct CatalogBrowser: View {
    @Environment(CalculatorViewModel.self) private var model

    var body: some View {
        @Bindable var model = model
        let entries = model.visibleCatalogEntries
        let files = model.visibleCatalogFiles

        HStack(spacing: 0) {
            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    TextField("Buscar peça, autor ou filamento", text: $model.catalogSearch)
                        .textFieldStyle(.roundedBorder)
                    Picker("Mostrar", selection: $model.catalogOnlyMine) {
                        Text("Todas").tag(false)
                        Text("Minhas").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                .padding(12)

                List(selection: Binding<String?>(
                    get: { model.selectedCatalogFileID ?? model.selectedCatalogEntryID?.uuidString },
                    set: { value in
                        model.selectedCatalogFileID = files.first { $0.id == value }?.id
                        model.selectedCatalogEntryID = value.flatMap { v in entries.first { $0.id.uuidString == v }?.id }
                    }
                )) {
                    ForEach(entries) { entry in
                        CatalogRow(entry: entry, isMine: model.isMine(entry)).tag(Optional(entry.id.uuidString))
                    }
                    if !files.isEmpty {
                        Section("Modelos na pasta (sem cálculo)") {
                            ForEach(files) { file in
                                CatalogFileRow(file: file).tag(Optional(file.id))
                            }
                        }
                    }
                }
                .overlay {
                    if entries.isEmpty && files.isEmpty {
                        ContentUnavailableView {
                            Label(model.catalogEntries.isEmpty ? "Catálogo vazio" : "Nada encontrado", systemImage: "books.vertical")
                        } description: {
                            Text(model.catalogEntries.isEmpty
                                 ? "Em “Peças”, selecione as peças e escolha “Publicar no catálogo”. Arquivos 3MF/STL colocados na pasta também aparecem aqui."
                                 : "Ajuste a busca ou o filtro.")
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
                CatalogFileDetail(file: file)
            } else if let id = model.selectedCatalogEntryID, let entry = model.catalogEntries.first(where: { $0.id == id }) {
                CatalogDetail(entry: entry).id(entry.id)
            } else {
                ContentUnavailableView(
                    "Selecione uma peça",
                    systemImage: "books.vertical",
                    description: Text("Veja a composição de custo e compare com o preço usando os seus parâmetros.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .toolbar {
            ToolbarItemGroup {
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
                .help("Pasta compartilhada do catálogo")
            }
        }
    }
}

private struct CatalogRow: View {
    let entry: CatalogEntry
    let isMine: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(entry.job.name.trimmingCharacters(in: .whitespaces).isEmpty ? "Peça sem nome" : entry.job.name)
                .font(.headline).lineLimit(1)
            HStack {
                Text(isMine ? "Você" : entry.authorName)
                Text("·")
                Text(entry.updatedAt.formatted(date: .abbreviated, time: .omitted))
                Spacer()
                Text(entry.authorPrice.map(Currency.format) ?? "—").monospacedDigit()
            }
            .font(.caption).foregroundStyle(Theme.muted)
        }
        .padding(.vertical, 3)
    }
}

private struct CatalogFileRow: View {
    let file: CatalogFile

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(file.name).font(.headline).lineLimit(1)
            HStack {
                Text(file.fileExtension.uppercased())
                Text("·")
                Text(file.modifiedAt.formatted(date: .abbreviated, time: .omitted))
                Spacer()
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
        VStack(spacing: 16) {
            ContentUnavailableView(
                file.name, systemImage: "cube",
                description: Text("Modelo \(file.fileExtension.uppercased()) solto na pasta, sem cálculo publicado. Calcule com os seus parâmetros para ver o custo e o preço; depois você pode publicá-lo no catálogo.")
            )
            Button { model.calculateCatalogFile(file) } label: {
                Label("Calcular com meus parâmetros", systemImage: "function")
            }
            .buttonStyle(.borderedProminent)
            Text(file.url.path).font(.caption).foregroundStyle(Theme.muted)
                .lineLimit(1).truncationMode(.middle).padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct CatalogDetail: View {
    @Environment(CalculatorViewModel.self) private var model
    let entry: CatalogEntry

    // Sem o macro @State (exige o Xcode completo); State funciona como propriedade comum.
    private let noteState = State(initialValue: "")
    private var note: String {
        get { noteState.wrappedValue }
        nonmutating set { noteState.wrappedValue = newValue }
    }

    var body: some View {
        let mine = model.isMine(entry)
        let comparison = entry.comparison(with: model.settings)

        Form {
            Section {
                LabeledContent("Autor", value: mine ? "\(entry.authorName) (você)" : entry.authorName)
                LabeledContent("Publicada em", value: entry.publishedAt.formatted(date: .long, time: .shortened))
                if entry.updatedAt != entry.publishedAt {
                    LabeledContent("Atualizada em", value: entry.updatedAt.formatted(date: .long, time: .shortened))
                }
                if mine {
                    TextField("Nota para quem vai usar", text: Binding(
                        get: { note },
                        set: { note = $0 }
                    ), axis: .vertical)
                    .lineLimit(1...4)
                    .onSubmit { model.updateCatalogNote(note, for: entry) }
                    if note != entry.note {
                        Button("Salvar nota") { model.updateCatalogNote(note, for: entry) }
                    }
                } else if !entry.note.isEmpty {
                    LabeledContent("Nota", value: entry.note)
                }
            } header: {
                BadgeLabel(entry.job.name.isEmpty ? "Peça sem nome" : entry.job.name, systemImage: "cube.fill", color: .cyan)
            }

            Section {
                LabeledContent("Preço do autor", value: entry.authorPrice.map(Currency.format) ?? "Indisponível")
                LabeledContent("Com os seus parâmetros", value: comparison.myPrice.map(Currency.format) ?? "Indisponível")
                if let delta = comparison.priceDelta {
                    LabeledContent("Diferença") {
                        Text((delta >= 0 ? "+" : "−") + Currency.format(abs(delta)))
                            .foregroundStyle(abs(delta) < 0.005 ? Theme.muted : (delta > 0 ? Theme.success : Theme.warn))
                    }
                }
            } header: {
                BadgeLabel("Preço", systemImage: model.settings.currency.systemImage, color: .green)
            } footer: {
                Text("Recalculado com os seus parâmetros fixos e o filamento padrão deles.")
                    .font(.caption).foregroundStyle(Theme.muted)
            }

            Section {
                LabeledContent("Peso da mesa", value: Weight.format(grams: entry.job.partWeight))
                LabeledContent("Tempo de impressão", value: "\(Int(entry.job.printHours)) h \(Int(entry.job.printMinutes)) min")
                LabeledContent("Peças por mesa", value: "\(entry.job.partsPerPlate)")
                if let filament = entry.job.filamentName {
                    LabeledContent("Filamento do autor", value: filament)
                }
            } header: {
                BadgeLabel("Impressão", systemImage: "cube.fill", color: .orange)
            }

            Section {
                ForEach(entry.result.items) { item in
                    LabeledContent(item.category.title, value: Currency.format(item.amount))
                }
                LabeledContent("Custo por peça", value: Currency.format(entry.result.unitCost)).fontWeight(.semibold)
            } header: {
                BadgeLabel("Custo segundo o autor", systemImage: "chart.pie.fill", color: .indigo)
            }

            Section {
                LabeledContent("Hora de máquina", value: Currency.format(entry.settings.machineCostPerHour) + "/h")
                LabeledContent("Valor da hora de trabalho", value: Currency.format(entry.settings.laborRate) + "/h")
                LabeledContent("Taxa de falha", value: "\(entry.settings.failureRatePercent.formatted())%")
                LabeledContent("Impostos + taxas", value: "\((entry.settings.taxPercent + entry.settings.marketplaceFeePercent).formatted())% + \(Currency.format(entry.settings.fixedFeePerSale))")
                LabeledContent("Margem de lucro", value: "\(entry.job.marginPercent.formatted())%")
            } header: {
                BadgeLabel("Parâmetros do autor", systemImage: "slider.horizontal.3", color: .gray)
            }

            Section {
                HStack {
                    Button { model.useCatalogEntryAsBase(entry) } label: {
                        Label("Usar como base", systemImage: "arrow.uturn.backward.circle.fill")
                    }
                    Button { model.saveCatalogEntryCopy(entry) } label: {
                        Label("Salvar no meu histórico", systemImage: "square.and.arrow.down.fill")
                    }
                    Spacer()
                    if mine {
                        Button(role: .destructive) { model.retractFromCatalog([entry.id]) } label: {
                            Label("Retirar do catálogo", systemImage: "trash.fill")
                        }
                    }
                }
            }
        }
        .themedForm()
        .onAppear { note = entry.note }
        .onChange(of: entry.note) { _, newValue in note = newValue }
    }
}
