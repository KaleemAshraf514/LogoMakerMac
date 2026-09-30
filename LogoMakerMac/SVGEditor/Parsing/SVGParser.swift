import Foundation
import CoreGraphics

/// Converts SVG XML into our reusable Swift model.
///
/// This uses Foundation's XMLDocument (a DOM parser) instead of WebKit.
/// DOM means we can inspect every XML node and its attributes ourselves.
/// Rendering happens later with Core Animation, not here.
final class SVGParser {
    enum ParseError: LocalizedError {
        case missingSVGRoot
        case invalidViewBox

        var errorDescription: String? {
            switch self {
            case .missingSVGRoot: return "The file does not contain an <svg> root element."
            case .invalidViewBox: return "The SVG viewBox could not be parsed."
            }
        }
    }

    func parse(data: Data, fileName: String) throws -> SVGDocumentModel {
        let xml = try XMLDocument(data: data, options: [.nodePreserveAll])
        guard let root = xml.rootElement(), root.name?.lowercased() == "svg" else {
            throw ParseError.missingSVGRoot
        }

        let viewBox = try parseViewBox(root)
        let gradients = parseGradients(root)

        var elements: [SVGElement] = []
        var counter = 0

        // Recursively visit XML children. This means SVG groups (<g>) can pass
        // inherited style/transform information down to their children.
        walk(element: root,
             inheritedAttributes: [:],
             inheritedTransform: .identity,
             insideDefs: false,
             counter: &counter,
             output: &elements)

        return SVGDocumentModel(fileName: fileName,
                                viewBox: viewBox,
                                elements: elements,
                                gradients: gradients)
    }

    private func parseViewBox(_ root: XMLElement) throws -> CGRect {
        if let raw = root.attribute(forName: "viewBox")?.stringValue {
            let n = numbers(raw)
            if n.count >= 4 {
                return CGRect(x: n[0], y: n[1], width: n[2], height: n[3])
            }
        }

        // Some SVGs provide width/height instead of viewBox.
        if let w = root.attribute(forName: "width")?.stringValue.flatMap(Double.init),
           let h = root.attribute(forName: "height")?.stringValue.flatMap(Double.init) {
            return CGRect(x: 0, y: 0, width: w, height: h)
        }

        throw ParseError.invalidViewBox
    }

    private func walk(element: XMLElement,
                      inheritedAttributes: [String: String],
                      inheritedTransform: CGAffineTransform,
                      insideDefs: Bool,
                      counter: inout Int,
                      output: inout [SVGElement]) {
        let name = (element.name ?? "").lowercased()
        let nowInsideDefs = insideDefs || name == "defs"

        var attrs = inheritedAttributes

        // First parse style="fill:#fff;stroke:#000" because many SVG exporters
        // put visual properties inside the style string.
        if let style = element.attribute(forName: "style")?.stringValue {
            for pair in style.split(separator: ";") {
                let pieces = pair.split(separator: ":", maxSplits: 1).map(String.init)
                if pieces.count == 2 { attrs[pieces[0].trimmingCharacters(in: .whitespaces)] = pieces[1].trimmingCharacters(in: .whitespaces) }
            }
        }

        // Direct XML attributes override inherited/group style.
        for node in element.attributes ?? [] {
            if let key = node.name, let value = node.stringValue {
                attrs[key] = value
            }
        }

        let localTransform = SVGTransformParser.parse(attrs["transform"])
        let combinedTransform = inheritedTransform.concatenating(localTransform)

        if !nowInsideDefs, let kind = SVGElementKind(rawValue: name) {
            counter += 1
            let sourceID = attrs["id"] ?? "\(kind.rawValue)-\(counter)"

            let fill = parsePaint(attrs["fill"] ?? inheritedAttributes["fill"] ?? "#000000")
            let stroke = parsePaint(attrs["stroke"] ?? "none")
            let strokeWidth = CGFloat(Double(attrs["stroke-width"] ?? "0") ?? 0)
            let opacity = CGFloat(Double(attrs["opacity"] ?? "1") ?? 1)

            output.append(
                SVGElement(id: UUID(),
                           sourceID: sourceID,
                           kind: kind,
                           attributes: attrs,
                           text: kind == .text ? element.stringValue : nil,
                           fill: fill,
                           stroke: stroke,
                           strokeWidth: strokeWidth,
                           opacity: opacity,
                           isVisible: true,
                           sourceTransform: combinedTransform,
                           editorTransform: EditorTransform(),
                           zIndex: output.count)
            )
        }

        for child in element.children ?? [] {
            if let childElement = child as? XMLElement {
                walk(element: childElement,
                     inheritedAttributes: attrs,
                     inheritedTransform: combinedTransform,
                     insideDefs: nowInsideDefs,
                     counter: &counter,
                     output: &output)
            }
        }
    }

    private func parsePaint(_ raw: String) -> SVGPaint {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.lowercased() == "none" { return .none }

        if value.hasPrefix("url(#"), value.hasSuffix(")") {
            let id = value.dropFirst(5).dropLast(1)
            return .gradient(String(id))
        }
        return .solid(value)
    }

    private func parseGradients(_ root: XMLElement) -> [String: SVGLinearGradient] {
        var result: [String: SVGLinearGradient] = [:]
        guard let nodes = try? root.nodes(forXPath: ".//*[local-name()='linearGradient']") else { return result }

        for node in nodes {
            guard let gradient = node as? XMLElement,
                  let id = gradient.attribute(forName: "id")?.stringValue else { continue }

            let x1 = CGFloat(Double(gradient.attribute(forName: "x1")?.stringValue ?? "0") ?? 0)
            let y1 = CGFloat(Double(gradient.attribute(forName: "y1")?.stringValue ?? "0") ?? 0)
            let x2 = CGFloat(Double(gradient.attribute(forName: "x2")?.stringValue ?? "1") ?? 1)
            let y2 = CGFloat(Double(gradient.attribute(forName: "y2")?.stringValue ?? "0") ?? 0)

            var stops: [SVGGradientStop] = []
            for child in gradient.children ?? [] {
                guard let stop = child as? XMLElement, stop.name?.lowercased() == "stop" else { continue }
                let offsetRaw = stop.attribute(forName: "offset")?.stringValue ?? "0"
                let color = stop.attribute(forName: "stop-color")?.stringValue ?? "#000000"
                let offset: CGFloat
                if offsetRaw.hasSuffix("%") {
                    offset = CGFloat(Double(offsetRaw.dropLast()) ?? 0) / 100
                } else {
                    offset = CGFloat(Double(offsetRaw) ?? 0)
                }
                stops.append(.init(offset: offset, colorHex: color))
            }

            result[id] = SVGLinearGradient(id: id, x1: x1, y1: y1, x2: x2, y2: y2, stops: stops)
        }
        return result
    }

    private func numbers(_ text: String) -> [CGFloat] {
        let regex = try! NSRegularExpression(pattern: #"[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?"#)
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let r = Range(match.range, in: text) else { return nil }
            return CGFloat(Double(text[r]) ?? 0)
        }
    }
}
