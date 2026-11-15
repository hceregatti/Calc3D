import Calc3DCore
import SwiftUI

/// Aparência de cada categoria na interface (mantida fora do Core).
extension CostCategory {
    var color: Color {
        switch self {
        case .filament: .blue
        case .energy: .orange
        case .depreciation: .purple
        case .maintenance: .gray
        case .overhead: .teal
        case .failures: .red
        case .labor: .pink
        case .supplies: .brown
        }
    }
}
