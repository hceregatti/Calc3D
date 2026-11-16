import Calc3DCore
import SwiftUI

/// Tela de parâmetros fixos: configurados uma vez e aplicados a todas as impressões.
struct ShopSettingsView: View {
    @Environment(CalculatorViewModel.self) private var model

    var body: some View {
        @Bindable var model = model
        let s = $model.settings

        Form {
            Section {
                HStack {
                    Label(
                        model.settingsHaveUnsavedChanges ? "Alterações não salvas" : "Parâmetros salvos",
                        systemImage: model.settingsHaveUnsavedChanges ? "exclamationmark.circle.fill" : "checkmark.circle.fill"
                    )
                    .foregroundColor(model.settingsHaveUnsavedChanges ? Theme.warn : Theme.muted)
                    Spacer()
                    if let feedback = model.settingsFeedback {
                        Text(feedback)
                            .font(.caption)
                            .foregroundStyle(Theme.success)
                    }
                }
            }

            Section {
                HourlyCostsSummary(settings: model.settings)
            } header: {
                BadgeLabel("Quanto custa uma hora de impressão", systemImage: "gauge.with.dots.needle.67percent", color: .indigo)
            } footer: {
                Text("Calculado a partir dos campos abaixo. As perdas por falha são somadas em cada impressão.")
                    .foregroundStyle(.secondary)
            }

            Section {
                NumberField(title: "Preço do rolo", value: s.spoolPrice, unit: "R$")
                NumberField(title: "Peso do rolo", value: s.spoolWeight, unit: "g")
            } header: {
                BadgeLabel("Filamento padrão", systemImage: "circle.circle.fill", color: .orange)
            }

            Section {
                NumberField(title: "Consumo médio", value: s.powerWatts, unit: "W",
                            hint: "PLA ~100–150 W; ABS/ASA ~200–300 W. Meça com uma tomada medidora.")
                NumberField(title: "Tarifa de energia", value: s.energyTariff, unit: "R$/kWh",
                            hint: "Valor final da conta: impostos + bandeira")
            } header: {
                BadgeLabel("Energia", systemImage: "bolt.fill", color: .yellow)
            }

            Section {
                NumberField(title: "Preço da impressora", value: s.printerPrice, unit: "R$")
                NumberField(title: "Valor de revenda", value: s.resaleValue, unit: "R$")
                NumberField(title: "Vida útil", value: s.lifetimeHours, unit: "h")
                NumberField(title: "Manutenção por ano", value: s.maintenancePerYear, unit: "R$",
                            hint: "Bicos, mesa/PEI, correias, ventoinhas, lubrificação")
                NumberField(title: "Horas impressas por ano", value: s.hoursPerYear, unit: "h")
            } header: {
                BadgeLabel("Máquina", systemImage: "printer.fill", color: .blue)
            }

            Section {
                NumberField(title: "Valor da sua hora", value: s.laborRate, unit: "R$/h")
                NumberField(title: "Embalagem por peça", value: s.packagingPerPart, unit: "R$")
            } header: {
                BadgeLabel("Mão de obra e embalagem", systemImage: "shippingbox.fill", color: .brown)
            }

            Section {
                NumberField(title: "Custos fixos mensais", value: s.fixedCostsPerMonth, unit: "R$",
                            hint: "Aluguel, software, internet, contador, DAS")
                NumberField(title: "Horas impressas por mês", value: s.hoursPerMonth, unit: "h")
                NumberField(title: "Taxa de falha", value: s.failureRatePercent, unit: "%",
                            hint: "Típico: 5–15%. Registre suas falhas por um mês.",
                            range: 0...90)
            } header: {
                BadgeLabel("Custos fixos e falhas", systemImage: "building.2.fill", color: .red)
            }

            Section {
                NumberField(title: "Impostos", value: s.taxPercent, unit: "%",
                            hint: "Ex.: Simples Nacional ~6%", range: 0...100)
                NumberField(title: "Taxa marketplace/cartão", value: s.marketplaceFeePercent, unit: "%",
                            range: 0...100)
                NumberField(title: "Taxa fixa por venda", value: s.fixedFeePerSale, unit: "R$",
                            hint: "Shopee/Mercado Livre cobram um valor fixo por item")
            } header: {
                BadgeLabel("Encargos de venda", systemImage: "percent", color: .green)
            }
        }
        .themedForm()
        .navigationTitle("Parâmetros fixos")
        .toolbar {
            ToolbarItem {
                Button {
                    model.saveSettings()
                } label: {
                    Label("Salvar parâmetros", systemImage: "checkmark.circle.fill")
                }
                .disabled(!model.settingsHaveUnsavedChanges)
                .help("Salva todos os parâmetros fixos alterados")
            }
            ToolbarItem {
                Button {
                    model.resetSettings()
                } label: {
                    Label("Restaurar padrões", systemImage: "arrow.counterclockwise.circle.fill")
                }
                .help("Volta todos os parâmetros fixos aos valores padrão")
            }
            ToolbarItem {
                Button {
                    model.screen = .printJob
                } label: {
                    Label("Calcular peça", systemImage: "cube.fill")
                }
                .help("Ir para o cálculo de peça (⌘2)")
            }
        }
    }
}

/// Decomposição do custo de uma hora de máquina.
private struct HourlyCostsSummary: View {
    let settings: ShopSettings

    var body: some View {
        row("Energia", settings.energyCostPerHour, .energy)
        row("Depreciação", settings.depreciationPerHour, .depreciation)
        row("Manutenção", settings.maintenancePerHour, .maintenance)
        row("Custos fixos", settings.overheadPerHour, .overhead)
        LabeledContent {
            Text(Currency.brl(settings.machineCostPerHour) + "/h")
                .bold()
                .monospacedDigit()
        } label: {
            Text("Total por hora de máquina").bold()
        }
    }

    private func row(_ title: String, _ value: Double, _ category: CostCategory) -> some View {
        LabeledContent {
            Text(Currency.brl(value) + "/h").monospacedDigit()
        } label: {
            HStack(spacing: 8) {
                Circle().fill(category.color).frame(width: 9, height: 9)
                Text(title)
            }
        }
    }
}
