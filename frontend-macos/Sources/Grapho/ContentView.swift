import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(alignment: .leading) {
            MetalView()
                .frame(minHeight: 160)
                .border(.secondary)
        }
    }
}
