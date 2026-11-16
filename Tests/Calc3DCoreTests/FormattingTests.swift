import Foundation
import Testing
@testable import Calc3DCore

@Suite("Máscaras e formatação")
struct FormattingTests {

    @Test("Números no padrão brasileiro")
    func numberFormat() {
        #expect(NumberMask.format(31.17) == "31,17")
        #expect(NumberMask.format(7000, minFraction: 2, maxFraction: 2) == "7.000,00")
        #expect(NumberMask.format(1234567.5, minFraction: 2, maxFraction: 2) == "1.234.567,50")
    }

    @Test("Parse do texto mascarado")
    func parse() {
        #expect(NumberMask.parse("7.000,00") == 7000)
        #expect(NumberMask.parse("31,17") == 31.17)
        #expect(NumberMask.parse(",5") == 0.5)
        #expect(NumberMask.parse("") == nil)
    }

    @Test("Máscara ao digitar")
    func live() {
        #expect(NumberMask.live("7000") == "7.000")
        #expect(NumberMask.live("1.0000", previous: "1.000") == "10.000")
        #expect(NumberMask.live("31,17") == "31,17")
        // Ponto digitado vira vírgula decimal.
        #expect(NumberMask.live("31.", previous: "31") == "31,")
        #expect(NumberMask.live("31.17") == "31,17")
        // Ponto de milhar já exibido não vira decimal ao apagar.
        #expect(NumberMask.live("7.00", previous: "7.000") == "700")
        #expect(NumberMask.live("7.000") == "7.000")
        // Limita as casas decimais.
        #expect(NumberMask.live("1,239") == "1,23")
        #expect(NumberMask.live("0,7509", maxFraction: 3) == "0,750")
        #expect(NumberMask.live(",5") == "0,5")
        #expect(NumberMask.live("007") == "7")
        #expect(NumberMask.live("12", maxFraction: 0) == "12")
    }

    @Test("Moeda configurável")
    func currency() {
        #expect(Currency.format(7000, currency: .brl).replacingOccurrences(of: "\u{00A0}", with: " ") == "R$ 7.000,00")
        let usd = Currency.format(7000, currency: .usd)
        #expect(usd.contains("7.000,00") && usd.contains("US$"))
    }

    @Test("Peso na unidade escolhida")
    func weight() {
        #expect(Weight.format(grams: 31.17, unit: .gram) == "31,17 g")
        #expect(Weight.format(grams: 1500, unit: .kilogram) == "1,5 kg")
        #expect(abs(WeightUnit.pound.toGrams(1) - 453.59237) < 0.0001)
    }

    @Test("Telefone")
    func phone() {
        #expect(TextMask.phone("11") == "(11")
        #expect(TextMask.phone("113") == "(11) 3")
        #expect(TextMask.phone("1130000000") == "(11) 3000-0000")
        #expect(TextMask.phone("11900000000") == "(11) 90000-0000")
        #expect(TextMask.phone("119000000001234") == "(11) 90000-0000")
        #expect(TextMask.phone("contato@x.com") == "contato@x.com")
    }

    @Test("CPF e CNPJ")
    func document() {
        #expect(TextMask.cpfCnpj("1234") == "123.4")
        #expect(TextMask.cpfCnpj("12345678901") == "123.456.789-01")
        #expect(TextMask.cpfCnpj("12345678000195") == "12.345.678/0001-95")
        // CNPJ alfanumérico (a partir de 2026).
        #expect(TextMask.cpfCnpj("12abc34501de35") == "12.ABC.345/01DE-35")
    }

    @Test("Parâmetros antigos sem moeda/unidade continuam carregando")
    func decodeLegacySettings() throws {
        let json = #"{"spoolPrice": 99, "spoolWeight": 1000}"#.data(using: .utf8)!
        let s = try JSONDecoder().decode(ShopSettings.self, from: json)
        #expect(s.spoolPrice == 99)
        #expect(s.currency == .brl)
        #expect(s.weightUnit == .gram)
        #expect(s.laborRate == ShopSettings.defaults.laborRate)
    }
}
