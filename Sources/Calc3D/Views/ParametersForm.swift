import Calc3DCore
import SwiftUI

/// Formulário com todos os parâmetros de entrada, agrupados por seção.
struct ParametersForm: View {
    @Environment(CalculatorViewModel.self) private var model

    var body: some View {
        @Bindable var model = model
        let p = $model.parameters

        Form {
            Section {
                NumberField(title: "Preço do rolo", value: p.spoolPrice, unit: "R$")
                NumberField(title: "Peso do rolo", value: p.spoolWeight, unit: "g")
                NumberField(title: "Peso da mesa (fatiador)", value: p.partWeight, unit: "g")
                NumberField(title: "Desperdício", value: p.wastePercent, unit: "%",
                            hint: "Purga, skirt/brim e troca de cor (AMS/MMU pode passar de 20%)",
                            range: 0...300)
            } header: {
                Label("Filamento", systemImage: "circle.dashed")
            }

            Section {
                NumberField(title: "Horas", value: p.printHours, unit: "h")
                NumberField(title: "Minutos", value: p.printMinutes, unit: "min", range: 0...59)
                LabeledContent {
                    Stepper(value: p.partsPerPlate, in: 1...999) {
                        Text("\(model.parameters.partsPerPlate) un")
                            .monospacedDigit()
                    }
                } label: {
                    Text("Peças por mesa")
                    Text("Peso e tempo são da mesa inteira; o custo é dividido pelas peças")
                }
            } header: {
                Label("Tempo e quantidade", systemImage: "clock")
            }

            Section {
                NumberField(title: "Consumo médio", value: p.powerWatts, unit: "W",
                            hint: "PLA ~100–150 W; ABS/ASA ~200–300 W. Meça com uma tomada medidora.")
                NumberField(title: "Tarifa de energia", value: p.energyTariff, unit: "R$/kWh",
                            hint: "Valor final da conta: impostos + bandeira")
            } header: {
                Label("Energia", systemImage: "bolt")
            }

            Section {
                NumberField(title: "Preço da impressora", value: p.printerPrice, unit: "R$")
                NumberField(title: "Valor de revenda", value: p.resaleValue, unit: "R$")
                NumberField(title: "Vida útil", value: p.lifetimeHours, unit: "h")
                NumberField(title: "Manutenção por ano", value: p.maintenancePerYear, unit: "R$",
                            hint: "Bicos, mesa/PEI, correias, ventoinhas, lubrificação")
                NumberField(title: "Horas impressas por ano", value: p.hoursPerYear, unit: "h")
            } header: {
                Label("Máquina", systemImage: "printer")
            }

            Section {
                NumberField(title: "Valor da sua hora", value: p.laborRate, unit: "R$/h")
                NumberField(title: "Preparação", value: p.setupMinutes, unit: "min",
                            hint: "Fatiar, preparar a mesa, retirar a peça")
                NumberField(title: "Pós-processamento", value: p.postProcessingMinutes, unit: "min",
                            hint: "Remover suportes, lixar, pintar")
                NumberField(title: "Insumos por mesa", value: p.consumablesPerPlate, unit: "R$",
                            hint: "Cola, lixa, tinta, primer, ímãs, parafusos")
                NumberField(title: "Embalagem por peça", value: p.packagingPerPart, unit: "R$")
            } header: {
                Label("Mão de obra e insumos", systemImage: "person")
            }

            Section {
                NumberField(title: "Custos fixos mensais", value: p.fixedCostsPerMonth, unit: "R$",
                            hint: "Aluguel, software, internet, contador, DAS")
                NumberField(title: "Horas impressas por mês", value: p.hoursPerMonth, unit: "h")
                NumberField(title: "Taxa de falha", value: p.failureRatePercent, unit: "%",
                            hint: "Típico: 5–15%. Registre suas falhas por um mês.",
                            range: 0...90)
            } header: {
                Label("Custos fixos e falhas", systemImage: "building.2")
            }

            Section {
                NumberField(title: "Margem de lucro", value: p.marginPercent, unit: "%",
                            hint: "Margem sobre o preço, não markup: 40% = custo ÷ 0,60",
                            range: 0...95)
                NumberField(title: "Impostos", value: p.taxPercent, unit: "%",
                            hint: "Ex.: Simples Nacional ~6%", range: 0...100)
                NumberField(title: "Taxa marketplace/cartão", value: p.marketplaceFeePercent, unit: "%",
                            range: 0...100)
                NumberField(title: "Taxa fixa por venda", value: p.fixedFeePerSale, unit: "R$",
                            hint: "Shopee/Mercado Livre cobram um valor fixo por item")
            } header: {
                Label("Preço de venda", systemImage: "dollarsign.circle")
            }
        }
        .formStyle(.grouped)
    }
}
