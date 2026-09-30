import AppKit
import QuartzCore
import CoreGraphics

/// NSView is used here because we want a genuinely interactive native canvas.
///
/// IMPORTANT:
/// - WebKit is NOT rendering the SVG.
/// - SwiftUI Image is NOT rendering the SVG.
/// - Each parsed SVG element becomes an actual Core Animation layer.
///
/// That is why an element can be selected, dragged, scaled, rotated and recolored.
final class SVGCanvasView: NSView {
    weak var store: SVGEditorStore?

    /// Normal editor canvases leave room around the SVG and draw a shadow.
    /// Export canvases use the exact SVG/viewBox size with no editor decoration.
    private var isExportCanvas = false

    // The source SVG coordinate space (for your files usually 0...1000).
    private let svgRootLayer = CALayer()

    // Maps Swift model ids to their actual visual CALayers.
    private var elementLayers: [UUID: CALayer] = [:]
    private var shapePaths: [UUID: CGPath] = [:]

    // Unedited source center for every element. Gestures add offsets relative to
    // this stable point; otherwise repeated SwiftUI updates could accidentally
    // compound/subtract the current offset and make dragging snap back.
    private var basePositions: [UUID: CGPoint] = [:]

    private let pathParser = SVGPathParser()
    private var currentDocument: SVGDocumentModel?

    private var dragStartCanvasPoint: CGPoint?
    private var dragStartOffset: CGPoint?

    override var isFlipped: Bool { true } // SVG coordinates also grow downward.

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        layer?.masksToBounds = true
        layer?.addSublayer(svgRootLayer)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        layoutSVGRoot()
    }

    // MARK: Synchronizing Swift model -> CALayers

    func synchronize(with document: SVGDocumentModel?, selectedID: UUID?) {
        guard let document else { return }

        // If a different file or different element order/count was loaded, rebuild.
        let oldIDs = currentDocument?.elements.map(\.id) ?? []
        let newIDs = document.elements.map(\.id)
        if currentDocument?.fileName != document.fileName || oldIDs != newIDs {
            rebuild(document)
        } else {
            // For normal inspector edits / gestures we update layers in place.
            for element in document.elements { updateLayer(for: element, document: document) }
        }

        currentDocument = document
        updateSelection(selectedID)
        layoutSVGRoot()
    }

    private func rebuild(_ document: SVGDocumentModel) {
        svgRootLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
        elementLayers.removeAll()
        shapePaths.removeAll()
        basePositions.removeAll()

        svgRootLayer.bounds = document.viewBox

        for element in document.elements.sorted(by: { $0.zIndex < $1.zIndex }) {
            if let layer = makeLayer(for: element, document: document) {
                svgRootLayer.addSublayer(layer)
                elementLayers[element.id] = layer
            }
        }
    }

    private func updateLayer(for element: SVGElement, document: SVGDocumentModel) {
        guard let layer = elementLayers[element.id] else { return }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.isHidden = !element.isVisible
        layer.opacity = Float(element.opacity)
        applyEditorTransform(element, to: layer)

        // Color is stored on the content sublayer tagged as "paint".
        if let shape = layer.sublayers?.first(where: { $0.name == "paint-shape" }) as? CAShapeLayer {
            applyShapePaint(element, shape: shape, container: layer, document: document)
        } else if let text = layer.sublayers?.first(where: { $0.name == "paint-text" }) as? CATextLayer {
            text.foregroundColor = resolvedColor(element.fill)?.cgColor
        }
        CATransaction.commit()
    }

    // MARK: Creating native Core Animation layers

    private func makeLayer(for element: SVGElement, document: SVGDocumentModel) -> CALayer? {
        switch element.kind {
        case .path:
            return makePathLayer(element, document: document)
        case .rect:
            return makeRectLayer(element, document: document)
        case .circle:
            return makeCircleLayer(element, document: document)
        case .ellipse:
            return makeEllipseLayer(element, document: document)
        case .line, .polygon, .polyline:
            return makeSimpleGeometryLayer(element, document: document)
        case .text:
            return makeTextLayer(element)
        case .image:
            return makeImageLayer(element)
        }
    }

    private func makePathLayer(_ element: SVGElement, document: SVGDocumentModel) -> CALayer? {
        guard let d = element.attributes["d"], let rawPath = pathParser.makePath(from: d) else { return nil }
        var sourceTransform = element.sourceTransform
        guard let transformed = rawPath.copy(using: &sourceTransform) else { return nil }
        return makeShapeContainer(element, path: transformed, document: document)
    }

    private func makeRectLayer(_ element: SVGElement, document: SVGDocumentModel) -> CALayer? {
        let x = number(element, "x"), y = number(element, "y")
        let w = number(element, "width"), h = number(element, "height")
        let rect = CGRect(x: x, y: y, width: w, height: h).applying(element.sourceTransform)
        let path = CGPath(rect: rect, transform: nil)
        return makeShapeContainer(element, path: path, document: document)
    }

    private func makeCircleLayer(_ element: SVGElement, document: SVGDocumentModel) -> CALayer? {
        let cx = number(element, "cx"), cy = number(element, "cy"), r = number(element, "r")
        let rect = CGRect(x: cx-r, y: cy-r, width: r*2, height: r*2).applying(element.sourceTransform)
        return makeShapeContainer(element, path: CGPath(ellipseIn: rect, transform: nil), document: document)
    }

    private func makeEllipseLayer(_ element: SVGElement, document: SVGDocumentModel) -> CALayer? {
        let cx = number(element, "cx"), cy = number(element, "cy")
        let rx = number(element, "rx"), ry = number(element, "ry")
        let rect = CGRect(x: cx-rx, y: cy-ry, width: rx*2, height: ry*2).applying(element.sourceTransform)
        return makeShapeContainer(element, path: CGPath(ellipseIn: rect, transform: nil), document: document)
    }

    private func makeSimpleGeometryLayer(_ element: SVGElement, document: SVGDocumentModel) -> CALayer? {
        let p = CGMutablePath()
        switch element.kind {
        case .line:
            p.move(to: CGPoint(x: number(element, "x1"), y: number(element, "y1")))
            p.addLine(to: CGPoint(x: number(element, "x2"), y: number(element, "y2")))
        case .polygon, .polyline:
            let values = extractNumbers(element.attributes["points"] ?? "")
            var idx = 0
            while idx + 1 < values.count {
                let point = CGPoint(x: values[idx], y: values[idx+1])
                if idx == 0 { p.move(to: point) } else { p.addLine(to: point) }
                idx += 2
            }
            if element.kind == .polygon { p.closeSubpath() }
        default: return nil
        }
        var t = element.sourceTransform
        guard let transformed = p.copy(using: &t) else { return nil }
        return makeShapeContainer(element, path: transformed, document: document)
    }

    private func makeShapeContainer(_ element: SVGElement, path: CGPath, document: SVGDocumentModel) -> CALayer {
        // A shape's CGPath is originally in SVG's global coordinate space.
        // We create a small container around JUST this object's bounds, then
        // translate the path into local coordinates. This gives every object its
        // own center, which makes rotation/scaling behave naturally.
        var bounds = path.boundingBoxOfPath
        if bounds.width < 1 { bounds.size.width = 1 }
        if bounds.height < 1 { bounds.size.height = 1 }

        var translation = CGAffineTransform(translationX: -bounds.minX, y: -bounds.minY)
        let localPath = path.copy(using: &translation) ?? path

        let container = CALayer()
        container.name = element.id.uuidString
        container.bounds = CGRect(origin: .zero, size: bounds.size)
        container.position = CGPoint(x: bounds.midX, y: bounds.midY)
        basePositions[element.id] = container.position
        container.opacity = Float(element.opacity)
        container.isHidden = !element.isVisible

        let shape = CAShapeLayer()
        shape.name = "paint-shape"
        shape.frame = container.bounds
        shape.path = localPath
        shape.lineJoin = .round
        if element.attributes["fill-rule"] == "evenodd" { shape.fillRule = .evenOdd }
        container.addSublayer(shape)

        // Store local path for pixel-ish hit testing, not just rectangle hit tests.
        shapePaths[element.id] = localPath
        applyShapePaint(element, shape: shape, container: container, document: document)
        applyEditorTransform(element, to: container)
        return container
    }

    private func applyShapePaint(_ element: SVGElement,
                                 shape: CAShapeLayer,
                                 container: CALayer,
                                 document: SVGDocumentModel) {
        // Remove previous gradient layer if this element used to be gradient-filled.
        container.sublayers?.filter { $0.name == "paint-gradient" }.forEach { $0.removeFromSuperlayer() }

        switch element.fill {
        case .none:
            shape.fillColor = nil
        case .solid(let value):
            shape.fillColor = NSColor(svgHex: value)?.cgColor ?? NSColor.black.cgColor
        case .gradient(let id):
            shape.fillColor = nil
            if let g = document.gradients[id] {
                let gradient = CAGradientLayer()
                gradient.name = "paint-gradient"
                gradient.frame = container.bounds
                gradient.colors = g.stops.compactMap { NSColor(svgHex: $0.colorHex)?.cgColor }
                gradient.locations = g.stops.map { NSNumber(value: Double($0.offset)) }

                // Supplied gradient uses user-space coordinates (0...1000). Convert
                // them into CAGradientLayer's normalized 0...1 coordinates.
                let vb = document.viewBox
                gradient.startPoint = CGPoint(x: (g.x1 - vb.minX) / vb.width,
                                              y: (g.y1 - vb.minY) / vb.height)
                gradient.endPoint = CGPoint(x: (g.x2 - vb.minX) / vb.width,
                                            y: (g.y2 - vb.minY) / vb.height)

                let mask = CAShapeLayer()
                mask.path = shape.path
                mask.frame = shape.frame
                mask.fillColor = NSColor.black.cgColor
                gradient.mask = mask
                container.insertSublayer(gradient, below: shape)
            }
        }

        switch element.stroke {
        case .solid(let value): shape.strokeColor = NSColor(svgHex: value)?.cgColor
        default: shape.strokeColor = nil
        }
        shape.lineWidth = element.strokeWidth
    }

    private func makeTextLayer(_ element: SVGElement) -> CALayer? {
        let value = element.text ?? ""
        let fontSize = number(element, "font-size", fallback: 40)
        let family = element.attributes["font-family"] ?? "Helvetica"
        let font = NSFont(name: family, size: fontSize) ?? NSFont.systemFont(ofSize: fontSize)

        // CATextLayer draws real text. If the exact SVG font is not installed,
        // macOS falls back to system font. That affects visual fidelity but the
        // text still remains an editable layer/object.
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: resolvedColor(element.fill) ?? NSColor.black
        ]
        let attributed = NSAttributedString(string: value, attributes: attributes)
        let measured = attributed.boundingRect(with: NSSize(width: 5000, height: 5000), options: [.usesLineFragmentOrigin])

        var origin = CGPoint(x: number(element, "x"), y: number(element, "y") - measured.height)
        origin = origin.applying(element.sourceTransform)

        let container = CALayer()
        container.name = element.id.uuidString
        container.bounds = CGRect(origin: .zero, size: CGSize(width: max(1, measured.width), height: max(1, measured.height)))
        container.position = CGPoint(x: origin.x + measured.width/2, y: origin.y + measured.height/2)
        basePositions[element.id] = container.position
        container.opacity = Float(element.opacity)

        let text = CATextLayer()
        text.name = "paint-text"
        text.frame = container.bounds
        text.string = value
        text.font = font
        text.fontSize = fontSize
        text.foregroundColor = resolvedColor(element.fill)?.cgColor
        text.contentsScale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        text.alignmentMode = .left
        text.truncationMode = .none
        container.addSublayer(text)
        applyEditorTransform(element, to: container)
        return container
    }

    private func makeImageLayer(_ element: SVGElement) -> CALayer? {
        let href = element.attributes["xlink:href"] ?? element.attributes["href"] ?? ""
        guard let comma = href.firstIndex(of: ","), href.contains("base64") else { return nil }
        let base64 = String(href[href.index(after: comma)...])
        guard let data = Data(base64Encoded: base64, options: .ignoreUnknownCharacters),
              let image = NSImage(data: data) else { return nil }

        let width = number(element, "width", fallback: image.size.width)
        let height = number(element, "height", fallback: image.size.height)
        let sourceRect = CGRect(x: number(element, "x"), y: number(element, "y"), width: width, height: height)
        let transformedRect = sourceRect.applying(element.sourceTransform)

        let container = CALayer()
        container.name = element.id.uuidString
        container.bounds = CGRect(origin: .zero, size: transformedRect.size)
        container.position = CGPoint(x: transformedRect.midX, y: transformedRect.midY)
        basePositions[element.id] = container.position
        container.opacity = Float(element.opacity)

        let imageLayer = CALayer()
        imageLayer.name = "paint-image"
        imageLayer.frame = container.bounds
        imageLayer.contents = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        imageLayer.contentsGravity = .resizeAspect
        container.addSublayer(imageLayer)
        applyEditorTransform(element, to: container)
        return container
    }

    // MARK: Editor transforms

    private func applyEditorTransform(_ element: SVGElement, to layer: CALayer) {
        let t = element.editorTransform
        // Position is used for translation; affineTransform for scale + rotation.
        if let original = basePositions[element.id] {
            layer.position = CGPoint(x: original.x + t.offsetX, y: original.y + t.offsetY)
        }
        layer.setAffineTransform(CGAffineTransform(rotationAngle: t.rotationDegrees * .pi / 180)
            .scaledBy(x: t.scale, y: t.scale))
    }

    // MARK: Canvas fitting

    private func layoutSVGRoot() {
        guard let document = currentDocument else { return }

        // The EDITOR canvas needs breathing room around the artboard so it feels
        // like Figma/Illustrator. The EXPORT canvas must have no padding because
        // the exported file should contain only the artboard itself.
        let padding: CGFloat = isExportCanvas ? 0 : 36
        let available = bounds.insetBy(dx: padding, dy: padding)
        let scale = min(available.width / document.viewBox.width,
                        available.height / document.viewBox.height)

        svgRootLayer.bounds = document.viewBox
        svgRootLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        svgRootLayer.setAffineTransform(CGAffineTransform(scaleX: scale, y: scale))
        svgRootLayer.backgroundColor = NSColor.white.cgColor

        // Shadows are editor decoration only. Including this shadow in an export
        // would change the actual artwork pixels, so the off-screen canvas omits it.
        svgRootLayer.shadowColor = NSColor.black.cgColor
        svgRootLayer.shadowOpacity = isExportCanvas ? 0 : 0.16
        svgRootLayer.shadowRadius = isExportCanvas ? 0 : 18
        svgRootLayer.shadowOffset = .zero
    }

    // MARK: Export helpers

    /// Builds a second, invisible canvas from the same edited model.
    ///
    /// Why create a second canvas?
    /// The on-screen canvas contains editor-only state such as the selected layer
    /// border and padding. Export should never contain those controls. A clean
    /// off-screen canvas lets us reuse the SAME CALayer renderer but without UI.
    static func makeExportCanvas(for document: SVGDocumentModel) -> SVGCanvasView {
        let size = NSSize(width: max(1, document.viewBox.width),
                          height: max(1, document.viewBox.height))
        let view = SVGCanvasView(frame: NSRect(origin: .zero, size: size))
        view.isExportCanvas = true
        view.synchronize(with: document, selectedID: nil)
        view.layoutSubtreeIfNeeded()
        view.layoutSVGRoot()
        return view
    }

    /// Creates bitmap pixels from the clean native view.
    /// `scale = 2` means a 1000×1000 SVG viewBox becomes a 2000×2000 bitmap.
    func makeBitmapRepresentation(scale: CGFloat) -> NSBitmapImageRep? {
        let safeScale = max(1, scale)
        let pixelWidth = max(1, Int(ceil(bounds.width * safeScale)))
        let pixelHeight = max(1, Int(ceil(bounds.height * safeScale)))

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelWidth,
            pixelsHigh: pixelHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }

        // `size` describes the logical point size; pixelsWide/pixelsHigh describe
        // the raster resolution. That is how one view can export at 1× or 2×.
        rep.size = bounds.size
        cacheDisplay(in: bounds, to: rep)
        return rep
    }

    /// Convenience used by SwiftUI's preview sheet.
    func makeBitmapImage(scale: CGFloat) -> NSImage? {
        guard let rep = makeBitmapRepresentation(scale: scale) else { return nil }
        let image = NSImage(size: bounds.size)
        image.addRepresentation(rep)
        return image
    }

    /// Creates a PDF by drawing the CLEAN Core Animation layer tree directly
    /// into a Core Graphics PDF context.
    ///
    /// Why not `dataWithPDF(inside:)`?
    /// An off-screen NSView is not attached to a window. AppKit's view-PDF
    /// capture can therefore ask the view to print before its layer-backed
    /// contents have participated in a normal window/display pass. The result
    /// can be a valid PDF page containing no artwork.
    ///
    /// Here we bypass that NSView printing lifecycle completely:
    ///
    /// edited model -> export SVGCanvasView -> CALayer tree
    ///              -> CG PDF context -> Data
    ///
    /// Quartz/Core Graphics PDF coordinates grow upward from the bottom-left,
    /// while this canvas is flipped and SVG coordinates grow downward. The
    /// translate + negative Y scale makes the PDF coordinate system match the
    /// canvas before we render the layer tree.
    func makePDFData() -> Data? {
        let mutableData = NSMutableData()

        guard let consumer = CGDataConsumer(data: mutableData as CFMutableData) else {
            return nil
        }

        var mediaBox = CGRect(origin: .zero, size: bounds.size)

        guard let pdfContext = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            return nil
        }

        // A PDF must explicitly begin and end a page.
        pdfContext.beginPDFPage(nil)

        // Match our flipped AppKit/SVG coordinate system (top-left origin).
        pdfContext.translateBy(x: 0, y: bounds.height)
        pdfContext.scaleBy(x: 1, y: -1)

        // Render the actual Core Animation tree. This includes CAShapeLayer,
        // CATextLayer, CAGradientLayer and image CALayers created by our renderer.
        // We render the root view layer so its SVG root sublayer is included.
        layer?.render(in: pdfContext)

        pdfContext.endPDFPage()
        pdfContext.closePDF()

        return mutableData as Data
    }

    // Convert a mouse point in NSView coordinates into SVG/viewBox coordinates.
    private func canvasPoint(from viewPoint: CGPoint) -> CGPoint {
        guard let viewLayer = layer else { return viewPoint }
        return svgRootLayer.convert(viewPoint, from: viewLayer)
    }

    // MARK: Selection and hit testing

    private func updateSelection(_ selectedID: UUID?) {
        for (id, layer) in elementLayers {
            CATransaction.begin(); CATransaction.setDisableActions(true)
            layer.borderWidth = id == selectedID ? 2 : 0
            layer.borderColor = id == selectedID ? NSColor.controlAccentColor.cgColor : nil
            layer.cornerRadius = id == selectedID ? 3 : 0
            CATransaction.commit()
        }
    }

    private func hitElement(at canvasPoint: CGPoint) -> UUID? {
        guard let document = currentDocument else { return nil }

        // Test topmost layer first, just like Photoshop/Figma selection.
        for element in document.elements.sorted(by: { $0.zIndex > $1.zIndex }) where element.isVisible {
            guard let host = elementLayers[element.id] else { continue }
            let local = host.convert(canvasPoint, from: svgRootLayer)
            guard host.bounds.contains(local) else { continue }

            if let path = shapePaths[element.id] {
                // CGPath.contains gives much better selection than only checking
                // the bounding rectangle of a complex logo shape.
                if path.contains(local, using: .winding, transform: .identity) {
                    return element.id
                }
            } else {
                // Text and raster image use their layer rectangle.
                return element.id
            }
        }
        return nil
    }

    // MARK: Mouse gesture: select + drag

    override func mouseDown(with event: NSEvent) {
        let viewPoint = convert(event.locationInWindow, from: nil)
        let point = canvasPoint(from: viewPoint)
        let hit = hitElement(at: point)
        store?.select(hit)
        updateSelection(hit)

        if let hit,
           let element = currentDocument?.elements.first(where: { $0.id == hit }) {
            dragStartCanvasPoint = point
            dragStartOffset = CGPoint(x: element.editorTransform.offsetX, y: element.editorTransform.offsetY)
        } else {
            dragStartCanvasPoint = nil; dragStartOffset = nil
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = dragStartCanvasPoint,
              let initial = dragStartOffset,
              let store else { return }

        let viewPoint = convert(event.locationInWindow, from: nil)
        let point = canvasPoint(from: viewPoint)
        let dx = point.x - start.x
        let dy = point.y - start.y
        store.setOffset(x: initial.x + dx, y: initial.y + dy)
    }

    override func mouseUp(with event: NSEvent) {
        dragStartCanvasPoint = nil
        dragStartOffset = nil
    }

    // MARK: Trackpad gestures

    override func magnify(with event: NSEvent) {
        // event.magnification is a delta such as 0.04; 1 + delta becomes scale factor.
        store?.multiplySelectedScale(by: max(0.1, 1 + event.magnification))
    }

    override func rotate(with event: NSEvent) {
        store?.rotateSelected(by: CGFloat(-event.rotation))
    }

    // MARK: Helpers

    private func number(_ e: SVGElement, _ key: String, fallback: CGFloat = 0) -> CGFloat {
        CGFloat(Double(e.attributes[key] ?? "") ?? Double(fallback))
    }

    private func extractNumbers(_ text: String) -> [CGFloat] {
        let regex = try! NSRegularExpression(pattern: #"[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?"#)
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap {
            guard let r = Range($0.range, in: text) else { return nil }
            return CGFloat(Double(text[r]) ?? 0)
        }
    }

    private func resolvedColor(_ paint: SVGPaint) -> NSColor? {
        paint.solidNSColor
    }
}
