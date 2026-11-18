import Foundation

/// Situação de um orçamento salvo: aguardando aprovação, vencido ou com venda confirmada.
public enum ProposalStatus: String, CaseIterable, Sendable {
    case waiting
    case expired
    case sold

    /// Último dia de validade (validade conta a partir da última atualização). Nil = sem validade.
    public static func validUntil(updatedAt: Date, validityDays: Int, calendar: Calendar = .current) -> Date? {
        guard validityDays > 0 else { return nil }
        return calendar.date(byAdding: .day, value: validityDays, to: updatedAt)
    }

    /// Dias de calendário até o vencimento: 0 = vence hoje, negativo = já venceu. Nil = sem validade.
    public static func daysUntilExpiry(updatedAt: Date, validityDays: Int, now: Date = .now, calendar: Calendar = .current) -> Int? {
        guard let until = validUntil(updatedAt: updatedAt, validityDays: validityDays, calendar: calendar) else { return nil }
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: until)).day
    }

    /// Venda confirmada vence qualquer prazo; o orçamento só vence depois do último dia de validade.
    public static func evaluate(
        updatedAt: Date, validityDays: Int, saleConfirmedAt: Date?, now: Date = .now, calendar: Calendar = .current
    ) -> ProposalStatus {
        if saleConfirmedAt != nil { return .sold }
        if let days = daysUntilExpiry(updatedAt: updatedAt, validityDays: validityDays, now: now, calendar: calendar), days < 0 {
            return .expired
        }
        return .waiting
    }
}
