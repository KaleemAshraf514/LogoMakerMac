import SwiftUI

/// Full SVG editor integrated inside the Logo Maker navigation stack.
///
/// The user arrives here by clicking an SVG card on Home. Because this view is
/// pushed through NavigationStack, macOS automatically gives us a Back button.
/// The editor itself still uses the same native SVG pipeline:
/// SVG XML -> Swift models -> Core Graphics -> Core Animation layers.
struct SVGEditorView: View {
    @StateObject private var editor: SVGEditorStore
    @State private var showsExportSheet = false

    init(initialFileName: String) {
        _editor = StateObject(wrappedValue: SVGEditorStore(initialFileName: initialFileName))
    }

    var body: some View {
        VStack(spacing: 0) {
            editorHeader
            Divider()

            HStack(spacing: 0) {
                LayersPanel(store: editor)
                    .background(AppTheme.cardBackground)

                Divider()

                ZStack(alignment: .topLeading) {
                    SVGCanvasRepresentable(store: editor)

                    Label("Native Vector Canvas", systemImage: "point.3.filled.connected.trianglepath.dotted")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background(AppTheme.brandGradient, in: Capsule())
                        .padding(14)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()

                InspectorPanel(store: editor)
                    .background(AppTheme.cardBackground)
            }
        }
        .background(AppTheme.screenBackground)
        .navigationTitle("SVG Canvas")
        .sheet(isPresented: $showsExportSheet) {
            SVGExportPreviewView(store: editor)
        }
        .alert("SVG Error", isPresented: Binding(
            get: { editor.errorMessage != nil },
            set: { if !$0 { editor.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { editor.errorMessage = nil }
        } message: {
            Text(editor.errorMessage ?? "Unknown error")
        }
    }

    private var editorHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 11)
                    .fill(AppTheme.brandGradient)
                    .frame(width: 40, height: 40)
                Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                    .foregroundStyle(.white)
                    .font(.system(size: 18, weight: .semibold))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(editor.document?.fileName.replacingOccurrences(of: ".svg", with: "") ?? "SVG Canvas")
                    .font(.headline)
                if let doc = editor.document {
                    Text("\(doc.elements.count) editable layers • \(Int(doc.viewBox.width))×\(Int(doc.viewBox.height))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                editor.refreshExportPreview()
                showsExportSheet = true
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
                    .padding(.horizontal, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.gradientStart)
            .disabled(editor.document == nil)
        }
        .padding(.horizontal, 18)
        .frame(height: 62)
        .background(AppTheme.cardBackground)
    }
}

/// Export preview keeps the Logo Maker color language while reusing the editor's
/// existing clean off-screen renderer. Preview and exported output therefore come
/// from the same edited SVG state.
struct SVGExportPreviewView: View {
    @ObservedObject var store: SVGEditorStore
    @Environment(\.dismiss) private var dismiss
    @State private var format: ExportFormat = .png
    @State private var jpegQuality: Double = 0.92

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Export Preview").font(.title3.bold())
                    Text("Preview of the clean canvas without editor selection borders.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }
            }
            .padding(18)
            .background(AppTheme.cardBackground)

            Divider()

            HStack(spacing: 0) {
                ZStack {
                    AppTheme.screenBackground
                    if let image = store.exportPreviewImage {
                        Image(nsImage: image)
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                            .padding(36)
                            .shadow(radius: 12, y: 6)
                    } else {
                        ProgressView("Preparing preview…")
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()

                VStack(alignment: .leading, spacing: 18) {
                    Text("Export Settings").font(.headline)

                    Picker("Format", selection: $format) {
                        ForEach(ExportFormat.allCases) { value in
                            Text(value.rawValue).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)

                    if format == .jpg {
                        HStack {
                            Text("JPEG Quality").font(.caption)
                            Spacer()
                            Text("\(Int(jpegQuality * 100))%").font(.caption.monospacedDigit())
                        }
                        Slider(value: $jpegQuality, in: 0.2...1.0)
                    }

                    if let doc = store.document {
                        Label("\(Int(doc.viewBox.width)) × \(Int(doc.viewBox.height)) canvas", systemImage: "aspectratio")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        store.exportCurrentDocument(as: format, jpegQuality: jpegQuality)
                    } label: {
                        Label("Export \(format.rawValue)…", systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.gradientStart)
                    .controlSize(.large)
                }
                .padding(20)
                .frame(width: 280)
                .background(AppTheme.cardBackground)
            }
        }
        .frame(minWidth: 840, minHeight: 600)
        .onAppear {
            if store.exportPreviewImage == nil { store.refreshExportPreview() }
        }
    }
}
