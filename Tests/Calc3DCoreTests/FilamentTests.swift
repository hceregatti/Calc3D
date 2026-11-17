import Testing
import Foundation
@testable import Calc3DCore

@Suite struct FilamentTests {
    @Test func precoPorGramaEBusca() throws {
        var f = Filament(material: .petg)
        f.brand = "Voolt3D"; f.name = "Basic"; f.colorName = "Preto"; f.price = 90; f.netWeight = 1000
        #expect(f.pricePerGram == 0.09)
        #expect(f.nozzleTempMin == 220)
        #expect(f.displayName == "Voolt3D Basic PETG · Preto")
        let query = try #require(f.searchURL).absoluteString
        #expect(query.contains("tbm=shop") && query.contains("Voolt3D"))
    }

    @Test func linkDeCompra() {
        var f = Filament()
        f.purchaseURL = "loja.com.br/produto"
        #expect(f.purchaseLink?.absoluteString == "https://loja.com.br/produto")
        f.purchaseURL = "javascript:alert(1)"
        #expect(f.purchaseLink == nil)
    }

    @Test func filamentoDaPecaSubstituiOPadrao() {
        var job = PrintJob.defaults
        let base = CostCalculator.calculate(settings: .defaults, job: job).items.first { $0.category == .filament }!.amount
        job.filamentPricePerGram = ShopSettings.defaults.filamentPricePerGram * 2
        let doubled = CostCalculator.calculate(settings: .defaults, job: job).items.first { $0.category == .filament }!.amount
        #expect(abs(doubled - base * 2) < 1e-9)
    }
}
