import Testing
import Foundation
@testable import Calc3DCore

@Suite struct FilamentUsageTests {
    private func filament(remaining: Double) -> Filament {
        var f = Filament(); f.brand = "X"; f.netWeight = 1000; f.remainingWeight = remaining; return f
    }

    @Test func gramasPorUnidadeComDesperdicioEPecasPorMesa() {
        var job = PrintJob.defaults
        #expect(FilamentUsage.gramsPerUnit(job: job) == nil)
        job.filamentID = UUID(); job.partWeight = 200; job.wastePercent = 10; job.partsPerPlate = 2
        #expect(abs(FilamentUsage.gramsPerUnit(job: job)! - 110) < 1e-9)
    }

    @Test func somaPorRoloIgnorandoItensSemFilamento() {
        let a = UUID(), b = UUID()
        let reqs = FilamentUsage.requirements([
            .init(filamentID: a, filamentName: "A", gramsPerUnit: 50, quantity: 3),
            .init(filamentID: a, filamentName: "A", gramsPerUnit: 10, quantity: 1),
            .init(filamentID: b, filamentName: "B", gramsPerUnit: 5, quantity: 2),
            .init(filamentID: nil, filamentName: "", gramsPerUnit: nil, quantity: 9),
        ])
        #expect(reqs.map(\.grams) == [160, 10])
    }

    @Test func baixaLimitadaAZeroEEstornoExato() {
        var filaments = [filament(remaining: 100)]
        let id = filaments[0].id
        let deductions = FilamentUsage.deduct([.init(filamentID: id, filamentName: "X", grams: 150)], from: &filaments)
        #expect(filaments[0].remainingWeight == 0)
        #expect(deductions[0].grams == 100 && deductions[0].requestedGrams == 150)
        FilamentUsage.revert(deductions, in: &filaments)
        #expect(filaments[0].remainingWeight == 100)
    }

    @Test func detectaEdicaoDepoisDaBaixa() {
        var filaments = [filament(remaining: 500)]
        let id = filaments[0].id
        let need = [FilamentUsage.Requirement(filamentID: id, filamentName: "X", grams: 100)]
        let deductions = FilamentUsage.deduct(need, from: &filaments)
        #expect(!FilamentUsage.hasChanged(since: deductions, requirements: need))
        #expect(FilamentUsage.hasChanged(since: deductions, requirements: [.init(filamentID: id, filamentName: "X", grams: 120)]))
    }

    @Test func faltaEAcabando() {
        #expect(FilamentUsage.shortage(required: 300, available: 180) == 120)
        #expect(FilamentUsage.shortage(required: 100, available: 180) == 0)
        #expect(filament(remaining: 100).isRunningLow)
        #expect(!filament(remaining: 400).isRunningLow)
    }
}
