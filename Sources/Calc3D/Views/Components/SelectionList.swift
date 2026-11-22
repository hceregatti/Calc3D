import AppKit
import SwiftUI

/// Lista com seleção na cor de destaque do app. A `List` do macOS pinta a seleção com a cor de destaque
/// do sistema (azul, por exemplo) e ignora o `tint`, então a seleção é desenhada aqui.
/// Suporta seleção simples ou múltipla (⌘-clique alterna, ⇧-clique seleciona o intervalo).
struct SelectionList<Item: Identifiable, Row: View>: View where Item.ID: Hashable {
    let items: [Item]
    @Binding var selection: Set<Item.ID>
    var allowsMultiple = false
    @ViewBuilder var row: (Item) -> Row

    // Sem o macro @State (exige o Xcode completo); State funciona como propriedade comum.
    private let anchorState = State<Item.ID?>(initialValue: nil)
    private var anchor: Item.ID? {
        get { anchorState.wrappedValue }
        nonmutating set { anchorState.wrappedValue = newValue }
    }

    init(items: [Item], selection: Binding<Set<Item.ID>>, allowsMultiple: Bool = true, @ViewBuilder row: @escaping (Item) -> Row) {
        self.items = items
        self._selection = selection
        self.allowsMultiple = allowsMultiple
        self.row = row
    }

    /// Seleção simples sobre um identificador opcional.
    init(items: [Item], selection: Binding<Item.ID?>, @ViewBuilder row: @escaping (Item) -> Row) {
        self.items = items
        self._selection = Binding(
            get: { selection.wrappedValue.map { [$0] } ?? [] },
            set: { selection.wrappedValue = $0.first }
        )
        self.allowsMultiple = false
        self.row = row
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(items) { item in
                    let isSelected = selection.contains(item.id)
                    row(item)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background {
                            RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous)
                                .fill(isSelected ? Theme.accent.opacity(0.12) : .clear)
                        }
                        .contentShape(.rect)
                        .onTapGesture { select(item) }
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(8)
        }
    }

    private func select(_ item: Item) {
        let flags = NSEvent.modifierFlags
        if allowsMultiple, flags.contains(.shift), let anchor,
           let from = items.firstIndex(where: { $0.id == anchor }), let to = items.firstIndex(where: { $0.id == item.id }) {
            selection = Set(items[min(from, to)...max(from, to)].map(\.id))
        } else if flags.contains(.command) {
            if selection.contains(item.id) { selection.remove(item.id) } else if allowsMultiple { selection.insert(item.id) } else { selection = [item.id] }
            anchor = item.id
        } else {
            selection = [item.id]
            anchor = item.id
        }
    }
}
