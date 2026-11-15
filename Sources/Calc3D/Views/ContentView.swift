import SwiftUI

struct ContentView: View {
    var body: some View {
        HStack(spacing: 0) {
            ParametersForm()
                .frame(minWidth: 520)
            Divider()
            ResultsPanel()
                .frame(width: 380)
        }
    }
}
