import Testing
@testable import Calc3DCore

@Suite("CostCalculator")
struct CostCalculatorTests {

    private func approx(_ a: Double, _ b: Double, tol: Double = 0.005) -> Bool { abs(a - b) <= tol }

    @Test("Valores padrão produzem os custos esperados")
    func defaults() {
        let r = CostCalculator.calculate(.defaults)
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

    @Test("Taxa de falha usa divisão por (1 − f)")
    func failureDivision() {
        var p = PrintParameters()
        p.failureRatePercent = 20
        let r = CostCalculator.calculate(p)
        let production = r.amount(for: .filament) + r.amount(for: .energy) + r.amount(for: .depreciation)
            + r.amount(for: .maintenance) + r.amount(for: .overhead)
        #expect(approx(production + r.amount(for: .failures), production / 0.8))
    }

    @Test("Custo é dividido pelas peças da mesa; embalagem é por peça")
    func perPart() {
        var p = PrintParameters()
        p.partsPerPlate = 4
        let one = CostCalculator.calculate(.defaults)
        let four = CostCalculator.calculate(p)
        #expect(approx(four.amount(for: .filament), one.amount(for: .filament) / 4))
        #expect(approx(four.amount(for: .supplies), (2 + 3 * 4) / 4))
        #expect(approx(four.plateCost, four.unitCost * 4))
    }

    @Test("Percentuais >= 100% retornam erro de precificação")
    func pricingError() {
        var p = PrintParameters()
        p.marginPercent = 80
        p.taxPercent = 10
        p.marketplaceFeePercent = 10
        let r = CostCalculator.calculate(p)
        #expect(r.suggestedPrice == nil)
        #expect(r.profitPerPart == nil)
    }

    @Test("Entradas inválidas não geram NaN nem valores negativos")
    func invalidInputs() {
        var p = PrintParameters()
        p.spoolWeight = 0
        p.lifetimeHours = 0
        p.resaleValue = 99_999
        p.failureRatePercent = 100
        p.partsPerPlate = 0
        p.partWeight = -.infinity
        let r = CostCalculator.calculate(p)
        #expect(r.items.allSatisfy { $0.amount.isFinite && $0.amount >= 0 })
        #expect(r.partsPerPlate == 1)
        #expect(r.amount(for: .depreciation) == 0)
    }

    @Test("Lucro por hora considera todas as peças da mesa")
    func profitPerHour() {
        var p = PrintParameters()
        p.partsPerPlate = 2
        let r = CostCalculator.calculate(p)
        #expect(approx(r.profitPerMachineHour!, r.profitPerPart! * 2 / 6.5))
    }

    @Test("Resumo contém preço sugerido em reais")
    func summary() {
        let r = CostCalculator.calculate(.defaults)
        let text = QuoteSummary.text(for: r, parameters: .defaults)
        #expect(text.contains("Preço sugerido: R$"))
        #expect(text.contains("Filamento"))
    }
}
