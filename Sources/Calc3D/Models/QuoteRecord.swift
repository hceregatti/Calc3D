import Calc3DCore
import Foundation

/// Immutable snapshot of a quote, including the settings used at calculation time.
struct QuoteRecord: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let savedAt: Date
    let job: PrintJob
    let settings: ShopSettings
    let result: CostResult

    init(
        id: UUID = UUID(),
        savedAt: Date = .now,
        job: PrintJob,
        settings: ShopSettings,
        result: CostResult
    ) {
        self.id = id
        self.savedAt = savedAt
        self.job = job
        self.settings = settings
        self.result = result
    }
}
