import Calc3DCore
import SwiftUI

/// Como o valor do campo é mascarado e exibido.
enum NumberFieldStyle {
    /// Número comum com até N casas decimais (ex.: 31,17).
    case decimal(Int = 2)
    /// Dinheiro: sempre duas casas (ex.: 7.000,00).
    case money
    /// Peso guardado em gramas, digitado na unidade dos parâmetros fixos.
    case weight
}

/// Linha de formulário com campo numérico, unidade e dica opcional.
struct NumberField: View {
    @Environment(CalculatorViewModel.self) private var model
    let title: String
    @Binding var value: Double
    let unit: String
    var hint: String? = nil
    var range: ClosedRange<Double> = 0...1_000_000
    var style: NumberFieldStyle = .decimal()

    var body: some View {
        LabeledContent {
            HStack(spacing: 6) {
                MaskedNumberInput(title: title, value: $value, style: style, range: range)
                    .frame(width: 110)
                Text(style.isWeight ? model.settings.weightUnit.symbol : unit)
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
}

/// Campo de texto com máscara numérica brasileira aplicada enquanto se digita.
///
/// `range` vale para o valor guardado (em gramas, no caso de peso).
struct MaskedNumberInput: View {
    @Environment(CalculatorViewModel.self) private var model
    let title: String
    @Binding var value: Double
    var style: NumberFieldStyle = .decimal()
    var range: ClosedRange<Double> = 0...1_000_000

    // Sem o macro @State (exige o Xcode completo); State funciona como propriedade comum.
    private let textState = State(initialValue: "")
    private var text: String {
        get { textState.wrappedValue }
        nonmutating set { textState.wrappedValue = newValue }
    }
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField(title, text: textBinding)
            .labelsHidden()
            .multilineTextAlignment(.trailing)
            .textFieldStyle(.roundedBorder)
            .monospacedDigit()
            .focused($isFocused)
            .onAppear { text = display(value) }
            .onChange(of: value) { _, newValue in
                if !isFocused { text = display(newValue) }
            }
            .onChange(of: isFocused) { _, focused in
                if !focused { text = display(value) }
            }
            .onChange(of: model.settings.weightUnit) { _, _ in text = display(value) }
            .onSubmit { text = display(value) }
    }

    private var unit: WeightUnit { model.settings.weightUnit }

    private var maxFraction: Int {
        switch style {
        case .decimal(let digits): digits
        case .money: 2
        case .weight: unit.fractionDigits
        }
    }

    private var textBinding: Binding<String> {
        Binding(
            get: { text },
            set: { newText in
                let masked = NumberMask.live(newText, previous: text, maxFraction: maxFraction)
                text = masked
                guard let typed = NumberMask.parse(masked) else { return }
                let stored = style.isWeight ? unit.toGrams(typed) : typed
                value = min(max(stored, range.lowerBound), range.upperBound)
            }
        )
    }

    private func display(_ stored: Double) -> String {
        switch style {
        case .decimal(let digits):
            NumberMask.format(stored, maxFraction: digits)
        case .money:
            NumberMask.format(stored, minFraction: 2, maxFraction: 2)
        case .weight:
            NumberMask.format(unit.fromGrams(stored), maxFraction: unit.fractionDigits)
        }
    }
}

/// Campo de texto livre com máscara (telefone, CPF/CNPJ…).
struct MaskedTextField: View {
    let title: String
    @Binding var text: String
    var prompt: String? = nil
    let mask: (String) -> String

    var body: some View {
        TextField(title, text: Binding(
            get: { text },
            set: { text = mask($0) }
        ), prompt: prompt.map { Text($0) })
    }
}

extension NumberFieldStyle {
    var isWeight: Bool {
        if case .weight = self { return true }
        return false
    }
}
