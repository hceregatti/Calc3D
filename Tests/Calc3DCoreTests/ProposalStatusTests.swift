import Testing
import Foundation
@testable import Calc3DCore

@Suite struct ProposalStatusTests {
    private var cal: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }
    private func date(_ day: Int, hour: Int = 12) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour))!
    }
    private func status(updated: Int, validity: Int, sold: Bool = false, now: Int, hour: Int = 12) -> ProposalStatus {
        ProposalStatus.evaluate(updatedAt: date(updated), validityDays: validity, saleConfirmedAt: sold ? date(now) : nil, now: date(now, hour: hour), calendar: cal)
    }

    @Test func aguardandoAteOUltimoDiaDeValidade() {
        #expect(status(updated: 1, validity: 15, now: 10) == .waiting)
        #expect(status(updated: 1, validity: 15, now: 16, hour: 23) == .waiting) // vence hoje
        #expect(ProposalStatus.daysUntilExpiry(updatedAt: date(1), validityDays: 15, now: date(16), calendar: cal) == 0)
    }

    @Test func vencidoNoDiaSeguinte() {
        #expect(status(updated: 1, validity: 15, now: 17, hour: 0) == .expired)
        #expect(ProposalStatus.daysUntilExpiry(updatedAt: date(1), validityDays: 15, now: date(19), calendar: cal) == -3)
    }

    @Test func semValidadeNuncaVence() {
        #expect(status(updated: 1, validity: 0, now: 30) == .waiting)
    }

    @Test func vendaConfirmadaGanhaDeTudo() {
        #expect(status(updated: 1, validity: 5, sold: true, now: 30) == .sold)
    }
}
