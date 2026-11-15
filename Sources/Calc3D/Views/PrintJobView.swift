import Calc3DCore
import SwiftUI

/// Tela de cada impressão: dados da peça à esquerda e resultado à direita.
struct PrintJobView: View {
    var body: some View {
        HStack(spacing: 0) {
            PrintJobForm()
                .frame(minWidth: 420)
            Divider()
            ResultsPanel()
                .frame(width: 380)
        }
        .navigationTitle("Calcular peça")
    }
}

private struct PrintJobForm: View {
    @Environment(CalculatorViewModel.self) private var model

    var body: some View {
        @Bindable var model = model
        let j = $model.job

        Form {
            Section {
                TextField("Nome da peça ou pedido", text: j.name, prompt: Text("Ex.: Suporte de headset"))
                Button {
                    model.importModel()
                } label: {
                    Label(model.isImportingModel ? "Lendo arquivo…" : "Importar STL ou 3MF", systemImage: "square.and.arrow.down")
                }
                .disabled(model.isImportingModel)
                if let feedback = model.importFeedback {
                    Text(feedback)
                        .font(.caption)
                        .foregroundColor(model.importedWeightNeedsInput || model.importedTimeNeedsInput ? Color.orange : Color.secondary)
                }
            } header: {
                Label("Identificação", systemImage: "tag")
            }

            Section {
                NumberField(title: "Peso da mesa", value: j.partWeight, unit: "g",
                            hint: model.importedWeightNeedsInput ? "Não encontrado no arquivo. Preencha o peso do fatiador." : "Valor do fatiador, somando todas as peças")
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
                Label("Fatiador", systemImage: "cube")
            }

            Section {
                NumberField(title: "Preparação", value: j.setupMinutes, unit: "min",
                            hint: "Fatiar, preparar a mesa, retirar a peça")
                NumberField(title: "Pós-processamento", value: j.postProcessingMinutes, unit: "min",
                            hint: "Remover suportes, lixar, pintar")
                NumberField(title: "Insumos desta mesa", value: j.consumablesPerPlate, unit: "R$",
                            hint: "Cola, lixa, tinta, primer, ímãs, parafusos")
            } header: {
                Label("Trabalho e acabamento", systemImage: "hand.raised")
            }

            Section {
                NumberField(title: "Margem de lucro", value: j.marginPercent, unit: "%",
                            hint: "Margem sobre o preço, não markup: 40% = custo ÷ 0,60",
                            range: 0...95)
            } header: {
                Label("Preço", systemImage: "dollarsign.circle")
            }

            Section {
                FixedSettingsSummary(settings: model.settings)
            } header: {
                HStack {
                    Label("Parâmetros fixos em uso", systemImage: "slider.horizontal.3")
                    Spacer()
                    Button("Editar…") { model.screen = .settings }
                        .buttonStyle(.link)
                }
            }
        }
        .formStyle(.grouped)
        .toolbar {
            ToolbarItem {
                Button {
                    model.newJob()
                } label: {
                    Label("Nova peça", systemImage: "plus")
                }
                .help("Começa o cálculo de uma nova peça (⌘N)")
            }
        }
    }
}

/// Resumo dos parâmetros fixos aplicados, para conferência rápida.
private struct FixedSettingsSummary: View {
    let settings: ShopSettings

    var body: some View {
        LabeledContent("Filamento", value: Currency.brl(settings.filamentPricePerGram * 1000) + "/kg")
        LabeledContent("Hora de máquina", value: Currency.brl(settings.machineCostPerHour) + "/h")
        LabeledContent("Valor da sua hora", value: Currency.brl(settings.laborRate) + "/h")
        LabeledContent("Taxa de falha", value: percent(settings.failureRatePercent))
        LabeledContent("Impostos + taxas", value:
            percent(settings.taxPercent + settings.marketplaceFeePercent)
            + " + " + Currency.brl(settings.fixedFeePerSale))
    }

    private func percent(_ v: Double) -> String {
        (v / 100).formatted(.percent.precision(.fractionLength(0...1)).locale(Currency.locale))
    }
}
