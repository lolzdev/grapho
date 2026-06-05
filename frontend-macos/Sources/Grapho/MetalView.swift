import MetalKit
import SwiftUI

struct MetalView: NSViewRepresentable {
    func makeNSView(context: Context) -> MTKView {
        let view = MTKView()
        view.device = MTLCreateSystemDefaultDevice()
        view.clearColor = MTLClearColor(red: 0.08, green: 0.10, blue: 0.12, alpha: 1.0)
        view.isPaused = true
        view.enableSetNeedsDisplay = true
        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        nsView.setNeedsDisplay(nsView.bounds)
    }
}

