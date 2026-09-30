import Foundation
import CoreGraphics

/// Parses the common SVG transform functions into CGAffineTransform.
/// Example source: transform="translate(303.35 245.88) scale(0.35)"
enum SVGTransformParser {
    static func parse(_ text: String?) -> CGAffineTransform {
        guard let text, !text.isEmpty else { return .identity }

        var result = CGAffineTransform.identity
        let pattern = #"([A-Za-z]+)\s*\(([^)]*)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return result }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)

        for match in regex.matches(in: text, range: range) {
            guard let nameRange = Range(match.range(at: 1), in: text),
                  let valuesRange = Range(match.range(at: 2), in: text) else { continue }

            let name = String(text[nameRange]).lowercased()
            let values = numbers(from: String(text[valuesRange]))
            var next = CGAffineTransform.identity

            switch name {
            case "translate":
                let x = values.count > 0 ? values[0] : 0
                let y = values.count > 1 ? values[1] : 0
                next = CGAffineTransform(translationX: x, y: y)

            case "scale":
                let x = values.count > 0 ? values[0] : 1
                let y = values.count > 1 ? values[1] : x
                next = CGAffineTransform(scaleX: x, y: y)

            case "rotate":
                guard let degrees = values.first else { break }
                let radians = degrees * .pi / 180
                if values.count >= 3 {
                    // rotate(angle, cx, cy) means rotate around a specific point.
                    let cx = values[1], cy = values[2]
                    next = CGAffineTransform(translationX: cx, y: cy)
                        .rotated(by: radians)
                        .translatedBy(x: -cx, y: -cy)
                } else {
                    next = CGAffineTransform(rotationAngle: radians)
                }

            case "matrix":
                if values.count >= 6 {
                    next = CGAffineTransform(a: values[0], b: values[1],
                                             c: values[2], d: values[3],
                                             tx: values[4], ty: values[5])
                }

            case "skewx":
                if let degrees = values.first {
                    next = CGAffineTransform(a: 1, b: 0,
                                             c: tan(degrees * .pi / 180), d: 1,
                                             tx: 0, ty: 0)
                }

            case "skewy":
                if let degrees = values.first {
                    next = CGAffineTransform(a: 1, b: tan(degrees * .pi / 180),
                                             c: 0, d: 1, tx: 0, ty: 0)
                }

            default:
                break
            }

            // SVG applies transform functions in their written sequence.
            result = result.concatenating(next)
        }
        return result
    }

    private static func numbers(from text: String) -> [CGFloat] {
        let regex = try! NSRegularExpression(pattern: #"[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?"#)
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let r = Range(match.range, in: text) else { return nil }
            return CGFloat(Double(text[r]) ?? 0)
        }
    }
}
