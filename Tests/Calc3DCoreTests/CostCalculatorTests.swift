import Testing
@testable import Calc3DCore

@Suite("CostCalculator")
struct CostCalculatorTests {

    private func approx(_ a: Double, _ b: Double, tol: Double = 0.005) -> Bool { abs(a - b) <= tol }

    private func calc(_ s: ShopSettings = .defaults, _ j: PrintJob = .defaults) -> CostResult {
        CostCalculator.calculate(settings: s, job: j)
    }

    @Test("Valores padrão produzem os custos esperados")
    func defaults() {
        let r = calc()
        // 85 g × 1,05 × 120 / 1000
        #expect(approx(r.amount(for: .filament), 10.71))
        // 0,15 kW × 6,5 h × 1,05
        #expect(approx(r.amount(for: .energy), 1.02375))
        // 2800 / 5000 × 6,5
        #expect(approx(r.amount(for: .depreciation), 3.64))
        // 400 / 1500 × 6,5
        #expect(approx(r.amount(for: .maintenance), 1.7333))
        // 150 / 125 × 6,5
        #expect(approx(r.amount(for: .overhead), 7.8))
        // 35 min × R$30/h
        #expect(approx(r.amount(for: .labor), 17.5))
        #expect(approx(r.amount(for: .supplies), 5))
        let production = 10.71 + 1.02375 + 3.64 + 1.73333 + 7.8
        #expect(approx(r.amount(for: .failures), production * 0.1 / 0.9))
        #expect(approx(r.suggestedPrice!, (r.unitCost + 4) / 0.4))
    }

    @Test("Custos por hora derivados dos parâmetros fixos")
    func perHourCosts() {
        let s = ShopSettings.defaults
        #expect(approx(s.filamentPricePerGram, 0.12))
        #expect(approx(s.energyCostPerHour, 0.1575))
        #expect(approx(s.depreciationPerHour, 0.56))
        #expect(approx(s.maintenancePerHour, 0.2667))
        #expect(approx(s.overheadPerHour, 1.2))
        #expect(approx(s.machineCostPerHour, 0.1575 + 0.56 + 0.26667 + 1.2))
    }

    @Test("Taxa de falha usa divisão por (1 − f)")
    func failureDivision() {
        var s = ShopSettings()
        s.failureRatePercent = 20
        let r = calc(s)
        let production = r.amount(for: .filament) + r.amount(for: .energy) + r.amount(for: .depreciation)
            + r.amount(for: .maintenance) + r.amount(for: .overhead)
        #expect(approx(production + r.amount(for: .failures), production / 0.8))
    }

    @Test("Custo é dividido pelas peças da mesa; embalagem é por peça")
    func perPart() {
        var j = PrintJob()
        j.partsPerPlate = 4
        let one = calc()
        let four = calc(.defaults, j)
        #expect(approx(four.amount(for: .filament), one.amount(for: .filament) / 4))
        #expect(approx(four.amount(for: .supplies), (2 + 3 * 4) / 4))
        #expect(approx(four.plateCost, four.unitCost * 4))
    }

    @Test("Percentuais >= 100% retornam erro de precificação")
    func pricingError() {
        var s = ShopSettings()
        s.taxPercent = 10
        s.marketplaceFeePercent = 10
        var j = PrintJob()
        j.marginPercent = 80
        let r = calc(s, j)
        #expect(r.suggestedPrice == nil)
        #expect(r.profitPerPart == nil)
    }

    @Test("Entradas inválidas não geram NaN nem valores negativos")
    func invalidInputs() {
        var s = ShopSettings()
        s.spoolWeight = 0
        s.lifetimeHours = 0
        s.resaleValue = 99_999
        s.failureRatePercent = 100
        var j = PrintJob()
        j.partsPerPlate = 0
        j.partWeight = -.infinity
        j.printMinutes = -30
        let r = calc(s, j)
        #expect(r.items.allSatisfy { $0.amount.isFinite && $0.amount >= 0 })
        #expect(r.partsPerPlate == 1)
        #expect(r.amount(for: .depreciation) == 0)
        #expect(r.printHours == 6)
    }

    @Test("Lucro por hora considera todas as peças da mesa")
    func profitPerHour() {
        var j = PrintJob()
        j.partsPerPlate = 2
        let r = calc(.defaults, j)
        #expect(approx(r.profitPerMachineHour!, r.profitPerPart! * 2 / 6.5))
    }

    @Test("Resumo usa o nome da peça e o preço em reais")
    func summary() {
        var j = PrintJob()
        j.name = "Suporte de headset"
        let text = QuoteSummary.text(for: calc(.defaults, j), job: j)
        #expect(text.hasPrefix("Orçamento: Suporte de headset"))
        #expect(text.contains("Preço sugerido: R$"))
        #expect(QuoteSummary.text(for: calc(), job: .defaults).hasPrefix("Orçamento impressão 3D"))
    }
}
