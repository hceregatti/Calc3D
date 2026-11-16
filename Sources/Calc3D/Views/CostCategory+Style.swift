import Calc3DCore
import SwiftUI

/// Aparência de cada categoria na interface (mantida fora do Core).
extension CostCategory {
    var color: Color {
        switch self {
        case .filament: Theme.chart[0]
        case .labor: Theme.chart[1]
        case .supplies: Theme.chart[2]
        case .depreciation: Theme.chart[3]
        case .overhead: Theme.chart[4]
        case .failures: Theme.chart[5]
        case .energy: Theme.chart[6]
        case .maintenance: Theme.chart[7]
        }
    }
}
