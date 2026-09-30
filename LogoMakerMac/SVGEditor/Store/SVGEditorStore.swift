import Foundation
import SwiftUI
import AppKit

/// Formats that the editor can export.
///
/// We keep this as an enum instead of using raw strings throughout the UI so
/// Swift can guarantee that only a supported format is selected.
enum ExportFormat: String, CaseIterable, Identifiable {
    case png = "PNG"
    case jpg = "JPG"
    case pdf = "PDF"

    var id: String { rawValue }

    /// File extension used by NSSavePanel.
    var fileExtension: String {
        switch self {
        case .png: return "png"
        case .jpg: return "jpg"
        case .pdf: return "pdf"
        }
    }
}

/// One ObservableObject owns the current document and editor state.
/// SwiftUI panels read/write this object; the native AppKit canvas also receives
/// changes through it. This is the bridge between declarative SwiftUI and the
/// interactive CALayer canvas.
@MainActor
final class SVGEditorStore: ObservableObject {
    @Published var document: SVGDocumentModel?
    @Published var selectedID: UUID?
    @Published var errorMessage: String?

    /// The export sheet displays this image.
    /// It is NOT a screenshot of the editor UI. We create a second clean
    /// SVGCanvasView off-screen and ask the same native renderer to draw the
    /// edited document without selection borders.
    @Published var exportPreviewImage: NSImage?

    let sampleFiles = [
        "Logos-Quran-40",
        "Logos-Quran-39",
        "Logos-Quran-38",
        "Logos-3D-38",
        "Logos-3D-40",
        "Logos-Alphabets-50",
        "Logos-Alphabets-51"
    ]

    private let parser = SVGParser()

    /// Immutable snapshot of the SVG exactly as it was when loaded.
    ///
    /// Why keep this?
    /// The editable `document` keeps changing as the user drags, recolors,
    /// hides, reorders, etc. A real Reset button needs a trustworthy copy of
    /// the ORIGINAL values. Without this snapshot we only know the current
    /// edited values, so we cannot restore the original fill/gradient/opacity.
    private var originalDocument: SVGDocumentModel?

    init(initialFileName: String = "Logos-Quran-40") {
        loadSample(named: initialFileName)
    }

    var selectedElement: SVGElement? {
        guard let selectedID, let document else { return nil }
        return document.elements.first(where: { $0.id == selectedID })
    }

    func loadSample(named name: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "svg") else {
            errorMessage = "Could not find \(name).svg in the app bundle."
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let parsed = try parser.parse(data: data, fileName: url.lastPathComponent)

            // `SVGDocumentModel` is a value type (struct), so assigning it to
            // both variables gives us an editable working copy plus an original
            // snapshot for Reset.
            originalDocument = parsed
            document = parsed
            selectedID = document?.elements.last?.id
            exportPreviewImage = nil
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func select(_ id: UUID?) {
        DispatchQueue.main.async{
            self.selectedID = id
        }
    }

    // MARK: Live visual editing

    func setFillColor(_ color: NSColor) {
        updateSelected { $0.fill = .solid(color.svgHexString) }
    }

    /// Changes ONE color stop inside a linear gradient.
    ///
    /// Example SVG:
    /// <linearGradient id="rainbow">
    ///   <stop offset="0" stop-color="#FF0000"/>
    ///   <stop offset="1" stop-color="#0000FF"/>
    /// </linearGradient>
    ///
    /// A gradient is not "one color". It owns an ordered array of stops.
    /// Updating one stop publishes a new document, causing the canvas renderer
    /// to rebuild the CAGradientLayer's `colors` array immediately.
    func setGradientStopColor(gradientID: String, stopIndex: Int, color: NSColor) {
        guard var doc = document,
              var gradient = doc.gradients[gradientID],
              gradient.stops.indices.contains(stopIndex) else { return }

        gradient.stops[stopIndex].colorHex = color.svgHexString
        doc.gradients[gradientID] = gradient
        document = doc
        exportPreviewImage = nil
    }

    func setOpacity(_ value: CGFloat) {
        updateSelected { $0.opacity = value }
    }

    func setVisibility(_ visible: Bool) {
        updateSelected { $0.isVisible = visible }
    }

    func setOffset(x: CGFloat? = nil, y: CGFloat? = nil) {
        updateSelected {
            if let x { $0.editorTransform.offsetX = x }
            if let y { $0.editorTransform.offsetY = y }
        }
    }

    func setScale(_ scale: CGFloat) {
        updateSelected { $0.editorTransform.scale = max(0.05, scale) }
    }

    func setRotation(_ degrees: CGFloat) {
        updateSelected { $0.editorTransform.rotationDegrees = degrees }
    }

    /// Canvas drag gestures call this with movement measured in SVG/viewBox units.
    func translateSelected(dx: CGFloat, dy: CGFloat) {
        updateSelected {
            $0.editorTransform.offsetX += dx
            $0.editorTransform.offsetY += dy
        }
    }

    /// Trackpad pinch gesture calls this continuously.
    func multiplySelectedScale(by factor: CGFloat) {
        updateSelected {
            $0.editorTransform.scale = max(0.05, min(20, $0.editorTransform.scale * factor))
        }
    }

    /// Trackpad rotation gesture calls this continuously.
    func rotateSelected(by deltaDegrees: CGFloat) {
        updateSelected { $0.editorTransform.rotationDegrees += deltaDegrees }
    }

    /// Restores the selected layer to the EXACT state it had in the source SVG.
    ///
    /// This intentionally resets much more than transform:
    /// - fill / stroke
    /// - gradient reference AND edited gradient stop colors
    /// - opacity
    /// - visibility
    /// - editor translation / scale / rotation
    /// - original z-order
    /// - original SVG attributes
    ///
    /// `sourceTransform` is also restored, although normal editor gestures do
    /// not modify it. Keeping Reset complete makes the source snapshot the single
    /// authority for "what did this layer originally look like?".
    func resetSelectedElement() {
        guard let selectedID,
              var doc = document,
              let originalDoc = originalDocument,
              let originalElement = originalDoc.elements.first(where: { $0.id == selectedID }),
              let currentIndex = doc.elements.firstIndex(where: { $0.id == selectedID }) else { return }

        // Remove the edited version and insert the pristine source element back
        // at its original SVG paint-order position.
        doc.elements.remove(at: currentIndex)
        let originalIndex = originalDoc.elements.firstIndex(where: { $0.id == selectedID }) ?? currentIndex
        doc.elements.insert(originalElement, at: min(originalIndex, doc.elements.count))

        // If this layer originally used a gradient, the user may have edited one
        // or more stop colors. Restore that whole gradient definition as well.
        if case .gradient(let gradientID) = originalElement.fill,
           let originalGradient = originalDoc.gradients[gradientID] {
            doc.gradients[gradientID] = originalGradient
        }

        // zIndex should match the actual array/paint order after reinsertion.
        for i in doc.elements.indices { doc.elements[i].zIndex = i }

        document = doc
        exportPreviewImage = nil
    }

    // MARK: Layer order

    /// SVG paints in document order: later siblings are visually on top.
    /// Reordering our elements therefore changes their CALayer z-order.
    func bringForward() {
        moveSelected(by: 1)
    }

    func sendBackward() {
        moveSelected(by: -1)
    }

    private func moveSelected(by delta: Int) {
        guard let selectedID, var doc = document,
              let index = doc.elements.firstIndex(where: { $0.id == selectedID }) else { return }
        let target = index + delta
        guard doc.elements.indices.contains(target) else { return }
        doc.elements.swapAt(index, target)
        for i in doc.elements.indices { doc.elements[i].zIndex = i }
        document = doc
    }

    private func updateSelected(_ edit: (inout SVGElement) -> Void) {
        guard let selectedID, var doc = document,
              let index = doc.elements.firstIndex(where: { $0.id == selectedID }) else { return }
        edit(&doc.elements[index])
        document = doc
        // The old preview is now stale because the canvas changed.
        exportPreviewImage = nil
    }

    // MARK: - Export / preview pipeline

    /// Generates a clean preview from the CURRENT edited document.
    ///
    /// Important mental model:
    /// editor document -> off-screen SVGCanvasView -> CALayers -> NSImage preview
    ///
    /// We deliberately reuse SVGCanvasView rather than creating a second renderer.
    /// Therefore what you edit, what you preview, and what you export all travel
    /// through the same rendering code.
    func refreshExportPreview() {
        guard let document else {
            exportPreviewImage = nil
            return
        }

        let exportCanvas = SVGCanvasView.makeExportCanvas(for: document)
        exportPreviewImage = exportCanvas.makeBitmapImage(scale: 1.0)
    }

    /// Opens the native macOS Save panel and writes the chosen format.
    /// PNG/JPG are bitmap encodings. PDF is produced from the clean native view.
    func exportCurrentDocument(as format: ExportFormat, jpegQuality: Double = 0.92) {
        guard let document else { return }

        // Create a NEW canvas instead of exporting the visible editor canvas.
        // This removes the blue selection border and editor-only decoration.
        let exportCanvas = SVGCanvasView.makeExportCanvas(for: document)

        let savePanel = NSSavePanel()
        savePanel.title = "Export Edited Artwork"
        savePanel.prompt = "Export"
        savePanel.canCreateDirectories = true
        savePanel.nameFieldStringValue = suggestedExportName(for: document, format: format)
        savePanel.allowedContentTypes = format.allowedContentTypes

        guard savePanel.runModal() == .OK, let url = savePanel.url else { return }

        do {
            let data: Data

            switch format {
            case .png:
                guard let bitmap = exportCanvas.makeBitmapRepresentation(scale: 2.0),
                      let png = bitmap.representation(using: .png, properties: [:]) else {
                    throw ExportError.couldNotCreateBitmap
                }
                data = png

            case .jpg:
                guard let bitmap = exportCanvas.makeBitmapRepresentation(scale: 2.0),
                      let jpg = bitmap.representation(
                        using: .jpeg,
                        properties: [.compressionFactor: max(0, min(1, jpegQuality))]
                      ) else {
                    throw ExportError.couldNotCreateBitmap
                }
                data = jpg

            case .pdf:
                // Do NOT use NSView.dataWithPDF here. Our export canvas lives
                // off-screen, so AppKit's view-printing path can produce a valid
                // but completely blank PDF.
                //
                // Instead SVGCanvasView creates a real Core Graphics PDF context
                // and asks the SAME Core Animation layer tree used by the canvas
                // to render directly into it.
                guard let pdf = exportCanvas.makePDFData() else {
                    throw ExportError.couldNotCreatePDF
                }
                data = pdf
            }

            try data.write(to: url, options: .atomic)
        } catch {
            errorMessage = "Export failed: \(error.localizedDescription)"
        }
    }

    private func suggestedExportName(for document: SVGDocumentModel, format: ExportFormat) -> String {
        let base = (document.fileName as NSString).deletingPathExtension
        return "\(base)-edited.\(format.fileExtension)"
    }
}

private enum ExportError: LocalizedError {
    case couldNotCreateBitmap
    case couldNotCreatePDF

    var errorDescription: String? {
        switch self {
        case .couldNotCreateBitmap:
            return "The canvas could not be converted into bitmap data."
        case .couldNotCreatePDF:
            return "The canvas could not be rendered into PDF data."
        }
    }
}

// UniformTypeIdentifiers is intentionally kept out of the main editor code.
// This extension only answers: "Which file type is valid for this format?"
import UniformTypeIdentifiers

private extension ExportFormat {
    var allowedContentTypes: [UTType] {
        switch self {
        case .png: return [.png]
        case .jpg: return [.jpeg]
        case .pdf: return [.pdf]
        }
    }
}
