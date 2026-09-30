import Foundation
import CoreGraphics
import AppKit

// MARK: - The mental model
//
// JSON usually becomes app-specific Swift structs.
// SVG is different: SVG is XML with a STANDARD set of visual tags such as
// <rect>, <path>, <text>, <image>, etc.
//
// We therefore make one reusable model that represents those common SVG
// element types. Every SVG file can be parsed into an array/tree of these
// elements instead of creating a brand-new Swift struct for every file.

enum SVGElementKind: String, CaseIterable {
    case rect
    case path
    case text
    case image
    case circle
    case ellipse
    case line
    case polygon
    case polyline

    var displayName: String { rawValue.capitalized }
}

// An SVG fill is not always a simple color. It may be "none", a solid color,
// or a reference such as fill="url(#linear-gradient)".
enum SVGPaint: Equatable {
    case none
    case solid(String)        // Example: "#02843d"
    case gradient(String)     // Stores the gradient id without '#'.
}

// We keep the SVG's ORIGINAL transform separately from edits made in our app.
// This is important: a text/image may already use translate(...) or scale(...)
// in the source SVG. User gestures are additional editor transforms.
struct EditorTransform: Equatable {
    var offsetX: CGFloat = 0
    var offsetY: CGFloat = 0
    var scale: CGFloat = 1
    var rotationDegrees: CGFloat = 0
}

// One renderable SVG object becomes one SVGElement.
//
// attributes intentionally remains [String:String]. SVG has a lot of optional
// attributes. Keeping the original dictionary means we don't silently throw
// away data we did not explicitly model yet.
struct SVGElement: Identifiable, Equatable {
    let id: UUID
    var sourceID: String
    var kind: SVGElementKind
    var attributes: [String: String]
    var text: String?

    // Parsed/common properties are convenient for the editor.
    var fill: SVGPaint
    var stroke: SVGPaint
    var strokeWidth: CGFloat
    var opacity: CGFloat
    var isVisible: Bool

    // Transform already present in the source SVG, e.g. translate(...).
    var sourceTransform: CGAffineTransform

    // Transform introduced by our editor/gestures.
    var editorTransform: EditorTransform

    // Original order in the SVG document. Later elements normally draw on top.
    var zIndex: Int
}

struct SVGGradientStop: Equatable {
    var offset: CGFloat
    var colorHex: String
}

struct SVGLinearGradient: Equatable {
    var id: String
    var x1: CGFloat
    var y1: CGFloat
    var x2: CGFloat
    var y2: CGFloat
    var stops: [SVGGradientStop]
}

struct SVGDocumentModel: Equatable {
    var fileName: String
    var viewBox: CGRect
    var elements: [SVGElement]
    var gradients: [String: SVGLinearGradient]
}

// MARK: - Color helpers

extension NSColor {
    /// Turns SVG-style hex such as #02843d / #fff into NSColor.
    convenience init?(svgHex: String) {
        var hex = svgHex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard hex.hasPrefix("#") else { return nil }
        hex.removeFirst()

        if hex.count == 3 {
            // #fff -> #ffffff
            hex = hex.map { "\($0)\($0)" }.joined()
        }

        guard hex.count == 6, let value = Int(hex, radix: 16) else { return nil }
        let r = CGFloat((value >> 16) & 0xFF) / 255
        let g = CGFloat((value >> 8) & 0xFF) / 255
        let b = CGFloat(value & 0xFF) / 255
        self.init(srgbRed: r, green: g, blue: b, alpha: 1)
    }

    var svgHexString: String {
        let c = usingColorSpace(.sRGB) ?? self
        return String(format: "#%02X%02X%02X",
                      Int(round(c.redComponent * 255)),
                      Int(round(c.greenComponent * 255)),
                      Int(round(c.blueComponent * 255)))
    }
}

extension SVGPaint {
    var solidNSColor: NSColor? {
        if case .solid(let value) = self {
            return NSColor(svgHex: value)
        }
        return nil
    }
}
