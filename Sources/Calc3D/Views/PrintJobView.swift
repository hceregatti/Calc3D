import Calc3DCore
import SwiftUI

/// Tela de cada impressão: dados da peça à esquerda e resultado à direita.
struct PrintJobView: View {
    @Environment(CalculatorViewModel.self) private var model

    var body: some View {
        HStack(spacing: 0) {
            PrintJobForm(calculator: model.calculator, onEditSettings: { model.screen = .settings })
                .frame(minWidth: 420)
            Divider()
            ResultsPanel()
                .frame(width: 380)
        }
        .navigationTitle("Calcular peça")
        .toolbar {
            ToolbarItem {
                Button {
                    model.newJob()
                } label: {
                    Label("Nova peça", systemImage: "plus.circle.fill")
                }
                .help("Começa o cálculo de uma nova peça (⌘N)")
            }
        }
    }
}

/// Formulário de cálculo de peça, compartilhado entre a tela principal e o orçamento.
struct PrintJobForm: View {
    @Environment(CalculatorViewModel.self) private var appModel
    let calculator: PartCalculator
    /// Quando nil, o atalho para editar os parâmetros fixos fica oculto.
    var onEditSettings: (() -> Void)?

    var body: some View {
        @Bindable var model = calculator
        let j = $model.job

        Form {
            Section {
                TextField("Nome da peça ou pedido", text: j.name, prompt: Text("Ex.: Suporte de headset"))
                Button {
                    model.importModel()
                } label: {
                    Label(model.isImportingModel ? "Lendo arquivo…" : "Importar STL ou 3MF", systemImage: "square.and.arrow.down.fill")
                }
                .disabled(model.isImportingModel)
                if let feedback = model.importFeedback {
                    Text(feedback)
                        .font(.caption)
                        .foregroundColor(model.importedWeightNeedsInput || model.importedTimeNeedsInput ? Theme.warn : Theme.muted)
                }
            } header: {
                BadgeLabel("Identificação", systemImage: "tag.fill", color: .blue)
            }

            Section {
                filamentPicker
                NumberField(title: "Peso da mesa", value: j.partWeight, unit: "g",
                            hint: model.importedWeightNeedsInput ? "Não encontrado no arquivo. Preencha o peso do fatiador." : "Valor do fatiador, somando todas as peças",
                            style: .weight)
                NumberField(title: "Desperdício", value: j.wastePercent, unit: "%",
                            hint: "Purga, skirt/brim e troca de cor (AMS/MMU pode passar de 20%)",
                            range: 0...300)
                NumberField(title: "Horas", value: j.printHours, unit: "h",
                            hint: model.importedTimeNeedsInput ? "Não encontrado no arquivo. Preencha o tempo do fatiador." : nil)
                NumberField(title: "Minutos", value: j.printMinutes, unit: "min", range: 0...59)
                LabeledContent {
                    Stepper(value: j.partsPerPlate, in: 1...999) {
                        Text("\(model.job.partsPerPlate) un")
                            .monospacedDigit()
                    }
                } label: {
                    Text("Peças por mesa")
                    Text("O custo da mesa é dividido entre as peças")
                }
            } header: {
                BadgeLabel("Fatiador", systemImage: "cube.fill", color: .orange)
            }

            Section {
                NumberField(title: "Preparação", value: j.setupMinutes, unit: "min",
                            hint: "Fatiar, preparar a mesa, retirar a peça")
                NumberField(title: "Pós-processamento", value: j.postProcessingMinutes, unit: "min",
                            hint: "Remover suportes, lixar, pintar")
                NumberField(title: "Insumos desta mesa", value: j.consumablesPerPlate, unit: Currency.symbol,
                            hint: "Cola, lixa, tinta, primer, ímãs, parafusos", style: .money)
            } header: {
                BadgeLabel("Trabalho e acabamento", systemImage: "paintbrush.pointed.fill", color: .pink)
            }

            Section {
                NumberField(title: "Margem de lucro", value: j.marginPercent, unit: "%",
                            hint: "Margem sobre o preço, não markup: 40% = custo ÷ 0,60",
                            range: 0...95)
            } header: {
                BadgeLabel("Preço", systemImage: model.settings.currency.systemImage, color: .green)
            }

            Section {
                FixedSettingsSummary(settings: model.settings, job: model.job)
            } header: {
                HStack {
                    BadgeLabel("Parâmetros fixos em uso", systemImage: "slider.horizontal.3", color: .gray)
                    Spacer()
                    if let onEditSettings {
                        Button("Editar…", action: onEditSettings)
                            .buttonStyle(.subtleLink)
                    }
                }
            }
        }
        .themedForm()
    }

    /// Escolha do filamento da biblioteca; sem escolha vale o rolo padrão dos parâmetros fixos.
    private var filamentPicker: some View {
        let job = calculator.job
        let missing = job.filamentID.flatMap { id in appModel.filament(withID: id) == nil ? id : nil }
        return LabeledContent {
            Picker("Filamento", selection: Binding<UUID?>(
                get: { job.filamentID },
                set: { appModel.useFilament(appModel.filament(withID: $0), in: calculator) }
            )) {
                Text("Padrão dos parâmetros fixos").tag(UUID?.none)
                if let missing {
                    Text("\(job.filamentName ?? "Filamento removido") (removido)").tag(UUID?.some(missing))
                }
                ForEach(appModel.filaments) { f in
                    Text(f.displayName).tag(UUID?.some(f.id))
                }
            }
            .labelsHidden()
            .frame(maxWidth: 260)
        } label: {
            Text("Filamento")
            Text(job.filamentPricePerGram.map { "Preço: " + Weight.pricePerBulkUnit(perGram: $0, unit: appModel.settings.weightUnit) }
                 ?? "Biblioteca em “Filamentos”")
        }
    }
}

/// Resumo dos parâmetros fixos aplicados, para conferência rápida.
private struct FixedSettingsSummary: View {
    let settings: ShopSettings
    let job: PrintJob

    var body: some View {
        LabeledContent("Filamento", value: Weight.pricePerBulkUnit(perGram: job.filamentPricePerGram ?? settings.filamentPricePerGram, unit: settings.weightUnit))
        LabeledContent("Hora de máquina", value: Currency.format(settings.machineCostPerHour) + "/h")
        LabeledContent("Valor da sua hora", value: Currency.format(settings.laborRate) + "/h")
        LabeledContent("Taxa de falha", value: percent(settings.failureRatePercent))
        LabeledContent("Impostos + taxas", value:
            percent(settings.taxPercent + settings.marketplaceFeePercent)
            + " + " + Currency.format(settings.fixedFeePerSale))
    }

    private func percent(_ v: Double) -> String {
        (v / 100).formatted(.percent.precision(.fractionLength(0...1)).locale(Currency.locale))
    }
}
