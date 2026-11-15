import SwiftUI

/// Linha de formulário com campo numérico, unidade e dica opcional.
struct NumberField: View {
    let title: String
    @Binding var value: Double
    let unit: String
    var hint: String? = nil
    var range: ClosedRange<Double> = 0...1_000_000

    var body: some View {
        LabeledContent {
            HStack(spacing: 6) {
                TextField(title, value: clampedBinding, format: .number.precision(.fractionLength(0...2)))
                    .labelsHidden()
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 96)
                Text(unit)
                    .foregroundStyle(.secondary)
                    .frame(width: 56, alignment: .leading)
            }
        } label: {
            Text(title)
            if let hint {
                Text(hint)
            }
        }
    }

    private var clampedBinding: Binding<Double> {
        Binding(
            get: { value },
            set: { value = min(max($0, range.lowerBound), range.upperBound) }
        )
    }
}
