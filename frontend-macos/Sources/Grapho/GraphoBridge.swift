import CoreGraphics
import Foundation

struct GraphoGlyphRecord {
    var glyphID: UInt32
    var x: Float
    var y: Float
    var xAdvance: Float
    var yAdvance: Float
    var reserved: Float
}

struct GraphoLayoutRecord {
    var glyphs: UnsafeMutablePointer<GraphoGlyphRecord>?
    var glyphCount: Int32
    var width: Float
    var height: Float
    var baseline: Float
    var originX: Float
    var originY: Float
    var fontName: UnsafeMutablePointer<CChar>?
    var fontSize: Float
}

struct ShapedGlyph {
    let glyphID: CGGlyph
    let position: CGPoint
}

struct ShapedText {
    let glyphs: [ShapedGlyph]
    let width: CGFloat
    let height: CGFloat
    let baseline: CGFloat
    let origin: CGPoint
    let fontName: String
    let fontSize: CGFloat
}

@_silgen_name("grapho_runtime_init")
private func c_grapho_runtime_init()

@_silgen_name("grapho_runtime_shutdown")
private func c_grapho_runtime_shutdown()

@_silgen_name("grapho_layout_text")
private func c_grapho_layout_text(
    _ output: UnsafeMutablePointer<GraphoLayoutRecord>
) -> Int32

@_silgen_name("grapho_free_layout")
private func c_grapho_free_layout(_ layout: UnsafeMutablePointer<GraphoLayoutRecord>)

@_silgen_name("grapho_zoom_in")
private func c_grapho_zoom_in() -> Float

@_silgen_name("grapho_zoom_out")
private func c_grapho_zoom_out() -> Float

extension Notification.Name {
    static let graphoFontConfigurationDidChange = Notification.Name(
        "graphoFontConfigurationDidChange"
    )
}

enum GraphoBridge {
    static func startRuntime() {
        c_grapho_runtime_init()
    }

    static func shutdownRuntime() {
        c_grapho_runtime_shutdown()
    }

    static func zoomIn() {
        dispatchPrecondition(condition: .onQueue(.main))
        _ = c_grapho_zoom_in()
        NotificationCenter.default.post(name: .graphoFontConfigurationDidChange, object: nil)
    }

    static func zoomOut() {
        dispatchPrecondition(condition: .onQueue(.main))
        _ = c_grapho_zoom_out()
        NotificationCenter.default.post(name: .graphoFontConfigurationDidChange, object: nil)
    }

    static func layout() -> ShapedText? {
        dispatchPrecondition(condition: .onQueue(.main))
        var record = GraphoLayoutRecord(
            glyphs: nil,
            glyphCount: 0,
            width: 0,
            height: 0,
            baseline: 0,
            originX: 0,
            originY: 0,
            fontName: nil,
            fontSize: 0
        )

        let status = c_grapho_layout_text(&record)

        guard status == 0 else {
            return nil
        }

        defer {
            c_grapho_free_layout(&record)
        }

        let count = Int(record.glyphCount)
        let fontName = record.fontName.map { String(cString: $0) } ?? ""
        let glyphs: [ShapedGlyph]

        if let records = record.glyphs, count > 0 {
            glyphs = (0..<count).map { index in
                let glyph = records[index]
                return ShapedGlyph(
                    glyphID: CGGlyph(glyph.glyphID),
                    position: CGPoint(x: CGFloat(glyph.x), y: CGFloat(glyph.y))
                )
            }
        } else {
            glyphs = []
        }

        return ShapedText(
            glyphs: glyphs,
            width: CGFloat(record.width),
            height: CGFloat(record.height),
            baseline: CGFloat(record.baseline),
            origin: CGPoint(
                x: CGFloat(record.originX),
                y: CGFloat(record.originY)
            ),
            fontName: fontName,
            fontSize: CGFloat(record.fontSize)
        )
    }
}
