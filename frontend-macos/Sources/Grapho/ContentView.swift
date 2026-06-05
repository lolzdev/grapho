import SwiftUI

struct ContentView: View {
    @State private var hello = GraphoBridge.hello()
    @State private var sum = GraphoBridge.add(2, 3)
    @State private var tick: Int32 = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Grapho")
                .font(.headline)

            Text(hello)
            Text("grapho_add(2, 3) = \(sum)")
            Text("grapho_tick() = \(tick)")

            Button("Tick") {
                tick = GraphoBridge.tick()
            }

            MetalView()
                .frame(minHeight: 160)
                .border(.secondary)
        }
        .padding()
    }
}
