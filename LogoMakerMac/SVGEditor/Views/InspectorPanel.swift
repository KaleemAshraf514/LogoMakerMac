import SwiftUI
import AppKit

struct InspectorPanel: View {
    @ObservedObject var store: SVGEditorStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("INSPECTOR")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                if let element = store.selectedElement {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(element.sourceID).font(.title3.weight(.semibold))
                        Text("SVG <\(element.kind.rawValue)> → native CALayer")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    Toggle("Visible", isOn: Binding(
                        get: { store.selectedElement?.isVisible ?? true },
                        set: { store.setVisibility($0) }
                    ))

                    // Paint editing is different for a solid fill vs a gradient.
                    //
                    // SOLID: one ColorPicker is enough because there is one color.
                    // GRADIENT: a gradient contains MANY color stops, so showing
                    // only the first stop would be misleading. We expose every
                    // parsed stop as its own native macOS ColorPicker.
                    if element.kind != .image {
                        switch element.fill {
                        case .gradient(let gradientID):
                            gradientEditor(gradientID: gradientID)

                        case .solid, .none:
                            ColorPicker("Fill Color", selection: Binding(
                                get: { currentSwiftUIColor(element) },
                                set: { newColor in
                                    if let ns = NSColor(newColor).usingColorSpace(.sRGB) {
                                        store.setFillColor(ns)
                                    }
                                }
                            ), supportsOpacity: false)
                        }
                    }

                    LabeledContent("Opacity") {
                        Text("\(Int(element.opacity * 100))%")
                            .monospacedDigit()
                    }
                    Slider(value: Binding(
                        get: { Double(store.selectedElement?.opacity ?? 1) },
                        set: { store.setOpacity(CGFloat($0)) }
                    ), in: 0...1)

                    Divider()
                    Text("TRANSFORM").font(.caption.weight(.semibold)).foregroundStyle(.secondary)

                    numericRow("X", value: element.editorTransform.offsetX) { store.setOffset(x: $0) }
                    numericRow("Y", value: element.editorTransform.offsetY) { store.setOffset(y: $0) }

                    LabeledContent("Scale") {
                        Text(String(format: "%.2fx", element.editorTransform.scale)).monospacedDigit()
                    }
                    Slider(value: Binding(
                        get: { Double(store.selectedElement?.editorTransform.scale ?? 1) },
                        set: { store.setScale(CGFloat($0)) }
                    ), in: 0.1...3)

                    LabeledContent("Rotation") {
                        Text("\(Int(element.editorTransform.rotationDegrees))°").monospacedDigit()
                    }
                    Slider(value: Binding(
                        get: { Double(store.selectedElement?.editorTransform.rotationDegrees ?? 0) },
                        set: { store.setRotation(CGFloat($0)) }
                    ), in: -180...180)

                    Button("Reset Layer") { store.resetSelectedElement() }
                        .buttonStyle(.bordered)

                    Text("Restores the original fill/gradient, opacity, visibility, transform and layer order from the SVG file.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Divider()

                    VStack(alignment: .leading, spacing: 7) {
                        Label("Drag on canvas → move", systemImage: "cursorarrow.motionlines")
                        Label("Trackpad pinch → scale", systemImage: "arrow.up.left.and.arrow.down.right")
                        Label("Trackpad rotate → rotate", systemImage: "rotate.right")
                        Label("Color wheel → live fill", systemImage: "paintpalette")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Divider()
                    DisclosureGroup("Parsed SVG attributes") {
                        VStack(alignment: .leading, spacing: 5) {
                            ForEach(element.attributes.keys.sorted(), id: \.self) { key in
                                HStack(alignment: .top) {
                                    Text(key).font(.caption.monospaced()).foregroundStyle(.secondary)
                                    Spacer(minLength: 8)
                                    Text(element.attributes[key] ?? "")
                                        .font(.caption.monospaced())
                                        .textSelection(.enabled)
                                        .lineLimit(4)
                                }
                            }
                        }
                        .padding(.top, 7)
                    }
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "square.dashed")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No Layer Selected").font(.headline)
                        Text("Click an SVG object or choose a layer from the left panel.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
                }
            }
            .padding(16)
        }
        .frame(minWidth: 270, idealWidth: 300, maxWidth: 340)
    }

    @ViewBuilder
    private func numericRow(_ title: String, value: CGFloat, onChange: @escaping (CGFloat) -> Void) -> some View {
        HStack {
            Text(title).frame(width: 18, alignment: .leading)
            TextField(title, value: Binding(get: { Double(value) }, set: { onChange(CGFloat($0)) }), format: .number.precision(.fractionLength(0...2)))
                .textFieldStyle(.roundedBorder)
        }
    }

    /// Builds one ColorPicker per <stop> in the selected SVG gradient.
    ///
    /// `offset` tells us WHERE that color sits in the gradient (0 = start,
    /// 1 = end). The renderer later sends both arrays to CAGradientLayer:
    /// gradient.colors    = all stop colors
    /// gradient.locations = all stop offsets
    @ViewBuilder
    private func gradientEditor(gradientID: String) -> some View {
        if let gradient = store.document?.gradients[gradientID] {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("GRADIENT COLORS")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(gradient.stops.count) stops")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                ForEach(Array(gradient.stops.enumerated()), id: \.offset) { index, stop in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Stop \(index + 1)")
                                .font(.caption.weight(.medium))
                            Text("\(Int(stop.offset * 100))%")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: 54, alignment: .leading)

                        ColorPicker("", selection: Binding(
                            get: {
                                Color(nsColor: NSColor(svgHex: stop.colorHex) ?? .black)
                            },
                            set: { newColor in
                                if let ns = NSColor(newColor).usingColorSpace(.sRGB) {
                                    store.setGradientStopColor(
                                        gradientID: gradientID,
                                        stopIndex: index,
                                        color: ns
                                    )
                                }
                            }
                        ), supportsOpacity: false)
                        .labelsHidden()

                        Text(stop.colorHex.uppercased())
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(10)
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
        } else {
            Text("Gradient ‘\(gradientID)’ could not be found in the parsed SVG definitions.")
                .font(.caption)
                .foregroundStyle(.red)
        }
    }

    private func currentSwiftUIColor(_ element: SVGElement) -> Color {
        if let ns = element.fill.solidNSColor { return Color(nsColor: ns) }
        if case .gradient(let id) = element.fill,
           let first = store.document?.gradients[id]?.stops.first,
           let ns = NSColor(svgHex: first.colorHex) {
            return Color(nsColor: ns)
        }
        return .black
    }
}
