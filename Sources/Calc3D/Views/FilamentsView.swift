import AppKit
import Calc3DCore
import SwiftUI

/// Biblioteca de filamentos: lista à esquerda e ficha do rolo à direita.
struct FilamentsView: View {
    @Environment(CalculatorViewModel.self) private var model

    var body: some View {
        @Bindable var model = model

        HStack(spacing: 0) {
            List(selection: $model.selectedFilamentID) {
                ForEach(model.filaments) { filament in
                    FilamentRow(filament: filament)
                        .tag(filament.id)
                        .contextMenu {
                            Button("Duplicar") { model.duplicateFilament(filament) }
                            Button("Buscar na web") { model.openFilamentSearch(filament) }
                            if filament.purchaseLink != nil {
                                Button("Abrir link de compra") { model.openFilamentPurchase(filament) }
                            }
                            Divider()
                            Button("Excluir…", role: .destructive) { model.filamentPendingDeletionID = filament.id }
                        }
                }
            }
            .overlay {
                if model.filaments.isEmpty {
                    ContentUnavailableView {
                        Label("Nenhum filamento", systemImage: "cylinder.split.1x2")
                    } description: {
                        Text("Cadastre os rolos que você tem: marca, peso, valor e parâmetros de impressão.")
                    } actions: {
                        Button("Adicionar filamento") { model.addFilament() }
                    }
                }
            }
            .frame(minWidth: 260, idealWidth: 300, maxWidth: 360)

            Divider()

            if let id = model.selectedFilamentID, let index = model.filaments.firstIndex(where: { $0.id == id }) {
                FilamentEditor(filament: $model.filaments[index])
                    .id(id)
            } else {
                ContentUnavailableView(
                    "Selecione um filamento",
                    systemImage: "cylinder.split.1x2",
                    description: Text("Escolha um rolo da lista para ver e editar a ficha.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Filamentos")
        .toolbar {
            ToolbarItem {
                Button { model.addFilament() } label: {
                    Label("Novo filamento", systemImage: "plus.circle.fill")
                }
                .help("Adicionar um rolo à biblioteca")
            }
        }
        .confirmationDialog(
            "Excluir filamento?",
            isPresented: Binding(
                get: { model.filamentPendingDeletionID != nil },
                set: { if !$0 { model.filamentPendingDeletionID = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Excluir", role: .destructive) {
                if let id = model.filamentPendingDeletionID { model.deleteFilament(id) }
                model.filamentPendingDeletionID = nil
            }
            Button("Cancelar", role: .cancel) { model.filamentPendingDeletionID = nil }
        } message: {
            Text("Peças já calculadas mantêm o preço usado na época.")
        }
    }
}

private func color(hex: String) -> Color {
    let value = UInt32(hex.dropFirst(), radix: 16) ?? 0x9A9994
    return Color(red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255, blue: Double(value & 0xFF) / 255)
}

private struct FilamentRow: View {
    let filament: Filament

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color(hex: filament.colorHex))
                .overlay(Circle().strokeBorder(Theme.border))
                .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(filament.displayName.isEmpty ? "Novo filamento" : filament.displayName)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text("\(Weight.format(grams: filament.remainingWeight)) restantes · \(Weight.pricePerBulkUnit(perGram: filament.pricePerGram))")
                        .font(.caption).foregroundStyle(Theme.muted).lineLimit(1)
                    if filament.isRunningLow {
                        Text("Acabando").font(.caption2.weight(.semibold)).foregroundStyle(Theme.warn)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}

/// Ficha completa do rolo.
private struct FilamentEditor: View {
    @Environment(CalculatorViewModel.self) private var model
    @Binding var filament: Filament

    var body: some View {
        Form {
            Section {
                TextField("Marca", text: $filament.brand, prompt: Text("Ex.: Voolt3D"))
                TextField("Linha / nome", text: $filament.name, prompt: Text("Ex.: Silk, Basic"))
                Picker("Material", selection: $filament.material) {
                    ForEach(FilamentMaterial.allCases) { Text($0.rawValue).tag($0) }
                }
                HStack {
                    TextField("Cor", text: $filament.colorName, prompt: Text("Ex.: Preto"))
                    ColorPicker("Cor", selection: Binding(
                        get: { color(hex: filament.colorHex) },
                        set: { filament.colorHex = hexString($0) }
                    ), supportsOpacity: false)
                    .labelsHidden()
                }
            } header: {
                BadgeLabel("Identificação", systemImage: "tag.fill", color: .indigo)
            }

            Section {
                NumberField(title: "Preço do rolo", value: $filament.price, unit: Currency.symbol, style: .money)
                NumberField(title: "Peso líquido", value: $filament.netWeight, unit: "g", style: .weight)
                NumberField(title: "Peso restante", value: $filament.remainingWeight, unit: "g",
                            hint: "Quanto ainda há no rolo", style: .weight)
                NumberField(title: "Diâmetro", value: $filament.diameter, unit: "mm", hint: "1,75 ou 2,85")
                LabeledContent("Preço por \(model.settings.weightUnit == .gram ? "grama" : "unidade de peso")",
                               value: Weight.pricePerBulkUnit(perGram: filament.pricePerGram, unit: model.settings.weightUnit))
                ProgressView(value: filament.remainingFraction)
                    .tint(color(hex: filament.colorHex))
            } header: {
                BadgeLabel("Rolo e preço", systemImage: "scalemass.fill", color: .green)
            }

            Section {
                NumberField(title: "Bico (mínimo)", value: $filament.nozzleTempMin, unit: "°C", range: 0...500)
                NumberField(title: "Bico (máximo)", value: $filament.nozzleTempMax, unit: "°C", range: 0...500)
                NumberField(title: "Mesa", value: $filament.bedTemp, unit: "°C", range: 0...200)
                NumberField(title: "Densidade", value: $filament.density, unit: "g/cm³", style: .decimal(2))
                Button("Usar valores típicos de \(filament.material.rawValue)") {
                    filament.applyTypicalProfile()
                }
                .buttonStyle(.subtleLink)
            } header: {
                BadgeLabel("Impressão", systemImage: "thermometer.medium", color: .orange)
            }

            Section {
                TextField("Loja", text: $filament.store, prompt: Text("Ex.: Mercado Livre"))
                TextField("Link de compra", text: $filament.purchaseURL, prompt: Text("https://…"))
                HStack {
                    Button { model.openFilamentSearch(filament) } label: {
                        Label("Buscar na web", systemImage: "magnifyingglass")
                    }
                    Button { model.openFilamentPurchase(filament) } label: {
                        Label("Abrir link", systemImage: "arrow.up.right.square")
                    }
                    .disabled(filament.purchaseLink == nil)
                    Spacer()
                }
                if !filament.purchaseURL.isEmpty && filament.purchaseLink == nil {
                    Text("Link inválido: use um endereço http ou https.")
                        .font(.caption).foregroundStyle(Theme.warn)
                }
            } header: {
                BadgeLabel("Compra", systemImage: "cart.fill", color: .blue)
            } footer: {
                Text("“Buscar na web” abre uma pesquisa com marca, material, cor e peso. Cole aqui o link do anúncio escolhido.")
                    .font(.caption).foregroundStyle(Theme.muted)
            }

            let history = model.stockHistory(for: filament.id)
            if !history.isEmpty {
                Section {
                    ForEach(Array(history.enumerated()), id: \.offset) { _, entry in
                        LabeledContent {
                            Text("−\(Weight.format(grams: entry.deduction.grams))").monospacedDigit()
                        } label: {
                            Text(entry.proposal.title.isEmpty ? "Orçamento sem título" : entry.proposal.title)
                            Text(entry.deduction.date.formatted(date: .abbreviated, time: .shortened))
                        }
                    }
                } header: {
                    BadgeLabel("Consumo", systemImage: "chart.bar.fill", color: .pink)
                } footer: {
                    Text("Baixas feitas por orçamentos neste rolo.").font(.caption).foregroundStyle(Theme.muted)
                }
            }

            Section {
                TextField("Observações", text: $filament.notes, axis: .vertical)
                    .lineLimit(3...8)
            } header: {
                BadgeLabel("Observações", systemImage: "note.text", color: .gray)
            }
        }
        .themedForm()
        .frame(maxWidth: .infinity)
    }

    private func hexString(_ c: Color) -> String {
        let ns = NSColor(c).usingColorSpace(.sRGB) ?? .gray
        return String(format: "#%02X%02X%02X", Int(ns.redComponent * 255), Int(ns.greenComponent * 255), Int(ns.blueComponent * 255))
    }
}
