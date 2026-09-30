import SwiftUI

struct LayersPanel: View {
    @ObservedObject var store: SVGEditorStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("LAYERS")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

            Divider()

            if let doc = store.document {
                List(selection: Binding(get: { store.selectedID }, set: { store.select($0) })) {
                    // Reverse visual order so the topmost layer appears at top of list,
                    // which matches common graphics apps such as Figma/Photoshop.
                    ForEach(doc.elements.sorted(by: { $0.zIndex > $1.zIndex })) { element in
                        HStack(spacing: 8) {
                            Image(systemName: icon(for: element.kind))
                                .frame(width: 18)
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(element.sourceID)
                                    .lineLimit(1)
                                Text(element.kind.displayName)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if !element.isVisible {
                                Image(systemName: "eye.slash")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tag(element.id)
                    }
                }
                .listStyle(.sidebar)
            }

            Divider()

            HStack {
                Button { store.sendBackward() } label: {
                    Image(systemName: "square.2.layers.3d.bottom.filled")
                }
                .help("Send selected layer backward")

                Button { store.bringForward() } label: {
                    Image(systemName: "square.2.layers.3d.top.filled")
                }
                .help("Bring selected layer forward")

                Spacer()
            }
            .buttonStyle(.borderless)
            .padding(12)
        }
        .frame(minWidth: 205, idealWidth: 225, maxWidth: 250)
    }

    private func icon(for kind: SVGElementKind) -> String {
        switch kind {
        case .text: return "textformat"
        case .image: return "photo"
        case .path: return "scribble.variable"
        case .rect: return "rectangle"
        case .circle, .ellipse: return "circle"
        case .line, .polyline: return "line.diagonal"
        case .polygon: return "pentagon"
        }
    }
}
