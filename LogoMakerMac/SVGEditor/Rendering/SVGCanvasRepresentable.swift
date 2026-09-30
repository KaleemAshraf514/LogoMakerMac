import SwiftUI

/// SwiftUI cannot directly host an NSView subclass in its view tree.
/// NSViewRepresentable is the official bridge: SwiftUI owns the surrounding UI,
/// while SVGCanvasView provides low-level AppKit/Core Animation interaction.
struct SVGCanvasRepresentable: NSViewRepresentable {
    @ObservedObject var store: SVGEditorStore

    func makeNSView(context: Context) -> SVGCanvasView {
        let view = SVGCanvasView(frame: .zero)
        view.store = store
        view.synchronize(with: store.document, selectedID: store.selectedID)
        return view
    }

    func updateNSView(_ nsView: SVGCanvasView, context: Context) {
        nsView.store = store
        nsView.synchronize(with: store.document, selectedID: store.selectedID)
    }
}
