import CoreText
import MetalKit
import SwiftUI

private struct TextVertex {
    var position: SIMD2<Float>
    var textureCoordinate: SIMD2<Float>
}

struct MetalView: NSViewRepresentable {
    func makeCoordinator() -> TextRenderer {
        TextRenderer()
    }

    func makeNSView(context: Context) -> MTKView {
        let view = MTKView()
        view.device = MTLCreateSystemDefaultDevice()
        view.clearColor = MTLClearColor(red: 0.08, green: 0.10, blue: 0.12, alpha: 1.0)
        view.colorPixelFormat = .bgra8Unorm
        view.isPaused = true
        view.enableSetNeedsDisplay = true
        view.delegate = context.coordinator
        context.coordinator.configure(view: view)
        return view
    }

    func updateNSView(_ view: MTKView, context: Context) {
        view.setNeedsDisplay(view.bounds)
    }
}

final class TextRenderer: NSObject, MTKViewDelegate {
    private let sdfSpread = 8
    private weak var view: MTKView?
    private let textureQueue = DispatchQueue(
        label: "dev.grapho.sdf",
        qos: .userInitiated
    )
    private var textureGeneration = 0
    private var commandQueue: MTLCommandQueue?
    private var pipelineState: MTLRenderPipelineState?
    private var texture: MTLTexture?
    private var textureSize = CGSize.zero

    override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(fontConfigurationDidChange),
            name: .graphoFontConfigurationDidChange,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func configure(view: MTKView) {
        guard let device = view.device else {
            return
        }

        self.view = view
        commandQueue = device.makeCommandQueue()
        pipelineState = makePipeline(device: device, pixelFormat: view.colorPixelFormat)
        if
            let layout = GraphoBridge.layout(),
            let generated = makeTextTexture(device: device, layout: layout)
        {
            texture = generated.texture
            textureSize = generated.size
        }
    }

    @objc private func fontConfigurationDidChange() {
        guard let view, let device = view.device else {
            return
        }

        textureGeneration += 1
        let generation = textureGeneration

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self, weak view] in
            guard
                let self,
                let view,
                self.textureGeneration == generation,
                let layout = GraphoBridge.layout()
            else {
                return
            }

            self.textureQueue.async { [weak self, weak view] in
                guard
                    let self,
                    let view,
                    let generated = self.makeTextTexture(device: device, layout: layout)
                else {
                    return
                }

                DispatchQueue.main.async { [weak self, weak view] in
                    guard
                        let self,
                        let view,
                        self.textureGeneration == generation
                    else {
                        return
                    }

                    self.texture = generated.texture
                    self.textureSize = generated.size
                    view.setNeedsDisplay(view.bounds)
                }
            }
        }
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    }

    func draw(in view: MTKView) {
        guard
            let commandQueue,
            let pipelineState,
            let texture,
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let descriptor = view.currentRenderPassDescriptor,
            let drawable = view.currentDrawable,
            let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
        else {
            return
        }

        let origin = SIMD2<Float>(20, 24)
        let size = SIMD2<Float>(Float(textureSize.width), Float(textureSize.height))
        let vertices = [
            TextVertex(position: origin, textureCoordinate: SIMD2(0, 0)),
            TextVertex(position: SIMD2(origin.x + size.x, origin.y), textureCoordinate: SIMD2(1, 0)),
            TextVertex(position: SIMD2(origin.x, origin.y + size.y), textureCoordinate: SIMD2(0, 1)),
            TextVertex(position: SIMD2(origin.x + size.x, origin.y), textureCoordinate: SIMD2(1, 0)),
            TextVertex(position: SIMD2(origin.x + size.x, origin.y + size.y), textureCoordinate: SIMD2(1, 1)),
            TextVertex(position: SIMD2(origin.x, origin.y + size.y), textureCoordinate: SIMD2(0, 1))
        ]
        var viewportSize = SIMD2<Float>(
            Float(view.drawableSize.width),
            Float(view.drawableSize.height)
        )

        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBytes(
            vertices,
            length: MemoryLayout<TextVertex>.stride * vertices.count,
            index: 0
        )
        encoder.setVertexBytes(
            &viewportSize,
            length: MemoryLayout<SIMD2<Float>>.stride,
            index: 1
        )
        encoder.setFragmentTexture(texture, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func makeTextTexture(
        device: MTLDevice,
        layout: ShapedText
    ) -> (texture: MTLTexture, size: CGSize)? {
        let font = CTFontCreateWithName(
            layout.fontName as CFString,
            layout.fontSize,
            nil
        )

        let padding = CGFloat(sdfSpread + 2)
        let width = max(1, Int(ceil(layout.width + padding * 2)))
        let height = max(1, Int(ceil(layout.height + padding * 2)))
        let bytesPerRow = width
        var coverage = [UInt8](repeating: 0, count: bytesPerRow * height)

        guard let context = CGContext(
            data: &coverage,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return nil
        }

        context.setShouldAntialias(true)
        context.setAllowsAntialiasing(true)
        context.setFillColor(gray: 1, alpha: 1)

        var glyphs = layout.glyphs.map(\.glyphID)
        var positions = layout.glyphs.map {
            CGPoint(
                x: padding + $0.position.x - layout.origin.x,
                y: padding + $0.position.y - layout.origin.y
            )
        }

        CTFontDrawGlyphs(font, &glyphs, &positions, glyphs.count, context)
        let sdf = makeSignedDistanceField(
            coverage: coverage,
            width: width,
            height: height,
            spread: sdfSpread
        )

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .r8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = .shaderRead

        guard let texture = device.makeTexture(descriptor: descriptor) else {
            return nil
        }

        texture.replace(
            region: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0,
            withBytes: sdf,
            bytesPerRow: bytesPerRow
        )
        return (texture, CGSize(width: width, height: height))
    }

    private func makeSignedDistanceField(
        coverage: [UInt8],
        width: Int,
        height: Int,
        spread: Int
    ) -> [UInt8] {
        let inside = distanceTransform(
            coverage: coverage,
            width: width,
            height: height,
            targetInside: true
        )
        let outside = distanceTransform(
            coverage: coverage,
            width: width,
            height: height,
            targetInside: false
        )
        var output = [UInt8](repeating: 0, count: coverage.count)

        for index in coverage.indices {
            let isInside = coverage[index] >= 128
            let distance = min(
                Float(spread),
                isInside ? outside[index] : inside[index]
            )
            let antialiasOffset = Float(coverage[index]) / 255 - 0.5
            let signedDistance = (isInside ? distance : -distance) + antialiasOffset
                let normalized = 0.5 + signedDistance / Float(spread * 2)
            output[index] = UInt8(clamping: Int((normalized * 255).rounded()))
        }

        return output
    }

    private func distanceTransform(
        coverage: [UInt8],
        width: Int,
        height: Int,
        targetInside: Bool
    ) -> [Float] {
        let infinity = Float.greatestFiniteMagnitude
        let diagonal = sqrt(Float(2))
        var distance = coverage.map { pixel in
            (pixel >= 128) == targetInside ? 0 : infinity
        }

        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                var value = distance[index]

                if x > 0 {
                    value = min(value, distance[index - 1] + 1)
                }
                if y > 0 {
                    value = min(value, distance[index - width] + 1)
                    if x > 0 {
                        value = min(value, distance[index - width - 1] + diagonal)
                    }
                    if x + 1 < width {
                        value = min(value, distance[index - width + 1] + diagonal)
                    }
                }

                distance[index] = value
            }
        }

        for y in stride(from: height - 1, through: 0, by: -1) {
            for x in stride(from: width - 1, through: 0, by: -1) {
                let index = y * width + x
                var value = distance[index]

                if x + 1 < width {
                    value = min(value, distance[index + 1] + 1)
                }
                if y + 1 < height {
                    value = min(value, distance[index + width] + 1)
                    if x > 0 {
                        value = min(value, distance[index + width - 1] + diagonal)
                    }
                    if x + 1 < width {
                        value = min(value, distance[index + width + 1] + diagonal)
                    }
                }

                distance[index] = value
            }
        }

        return distance
    }

    private func makePipeline(
        device: MTLDevice,
        pixelFormat: MTLPixelFormat
    ) -> MTLRenderPipelineState? {
        let source = """
        #include <metal_stdlib>
        using namespace metal;

        struct TextVertex {
            float2 position;
            float2 textureCoordinate;
        };

        struct RasterData {
            float4 position [[position]];
            float2 textureCoordinate;
        };

        vertex RasterData text_vertex(
            uint vertexID [[vertex_id]],
            constant TextVertex *vertices [[buffer(0)]],
            constant float2 &viewportSize [[buffer(1)]]
        ) {
            TextVertex input = vertices[vertexID];
            float2 normalized = input.position / viewportSize;

            RasterData output;
            output.position = float4(
                normalized.x * 2.0 - 1.0,
                1.0 - normalized.y * 2.0,
                0.0,
                1.0
            );
            output.textureCoordinate = input.textureCoordinate;
            return output;
        }

        fragment float4 text_fragment(
            RasterData input [[stage_in]],
            texture2d<float> textTexture [[texture(0)]]
        ) {
            constexpr sampler textureSampler(
                mag_filter::linear,
                min_filter::linear
            );
            float distance = textTexture.sample(
                textureSampler,
                input.textureCoordinate
            ).r;
            float smoothing = max(fwidth(distance), 1.0 / 255.0);
            float alpha = smoothstep(
                0.5 - smoothing,
                0.5 + smoothing,
                distance
            );
            return float4(0.93, 0.95, 0.98, alpha);
        }
        """

        guard
            let library = try? device.makeLibrary(source: source, options: nil),
            let vertexFunction = library.makeFunction(name: "text_vertex"),
            let fragmentFunction = library.makeFunction(name: "text_fragment")
        else {
            return nil
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.colorAttachments[0].pixelFormat = pixelFormat
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        return try? device.makeRenderPipelineState(descriptor: descriptor)
    }
}
