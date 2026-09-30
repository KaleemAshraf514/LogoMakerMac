# LogoMakerMac

A native macOS logo-maker experience built with **SwiftUI**, with an integrated **editable SVG canvas** powered by **AppKit, Core Graphics, and Core Animation**.

The project combines a template-browsing interface with a native vector editing workflow: choose an SVG template from Home, edit individual layers on the canvas, then export the result as PNG, JPEG, or PDF.

## Highlights

- Native macOS interface built primarily with SwiftUI
- Responsive sidebar with Home, Create, and Favourites sections
- Template categories, quick filters, search, galleries, and favourites
- Horizontal template browsing designed for macOS trackpad/mouse interaction
- Dedicated **SVG Canvas** category on Home
- Seven bundled editable SVG templates with preview cards
- Native SVG XML parsing into Swift document and element models
- Core Graphics path rendering with Core Animation layers
- Layer selection and hit testing
- Drag, scale, and rotation editing
- Solid fill and multi-stop gradient color editing
- Opacity and visibility controls
- Layer ordering with bring-forward / send-backward controls
- Full per-layer reset to the original SVG state
- Clean export preview
- PNG, JPEG, and PDF export using the current edited document
- Purple-to-pink Logo Maker design system shared across the app and editor

## SVG Canvas

The SVG editor is integrated directly into the existing app navigation.

```text
Home
  ↓
SVG Canvas category
  ↓
Choose an SVG template
  ↓
SVGEditorView
  ↓
Edit layers
  ↓
Preview / Export
```

The normal macOS navigation flow provides a Back button to return from the editor to Home.

### Editing model

The parsed Swift document is the editor's source of truth. The Core Animation layer tree is a visual representation of that document rather than the authoritative state.

```text
SVG XML
   ↓
SVGParser
   ↓
SVGDocumentModel + SVGElement
   ↓
CGPath / Core Animation layers
   ↓
Interactive native canvas
   ↕
SVGEditorStore
   ↓
Clean export renderer
   ↓
PNG / JPEG / PDF
```

This keeps editing, previewing, resetting, and exporting tied to the same document state.

## Native Rendering

The editor maps SVG content to native macOS drawing primitives, including:

| SVG / model content | Native rendering |
| --- | --- |
| Paths and vector shapes | `CGPath` + `CAShapeLayer` |
| Text | `CATextLayer` |
| Linear gradients | `CAGradientLayer` |
| Images / visual layers | `CALayer` |

SwiftUI hosts the editor UI, while `NSView` and Core Animation handle the interactive canvas.

## Layer Reset

Each loaded SVG keeps an immutable copy of its original parsed document. **Reset Layer** restores the selected element from that source snapshot, including its original:

- fill and stroke
- gradient reference and gradient stop colors
- opacity and visibility
- translation, scale, and rotation
- z-order / paint order
- source attributes and source transform

This makes reset a true return to the original SVG layer rather than only resetting its position.

## Export

The editor creates a clean off-screen canvas from the latest edited document so editor-only selection borders are not included in the output.

Supported formats:

- **PNG** — bitmap export at 2× scale
- **JPEG** — bitmap export at 2× scale with adjustable quality
- **PDF** — rendered directly through a Core Graphics PDF context

The export preview and final file use the same native rendering pipeline.

## Bundled SVG Templates

The current SVG Canvas includes:

```text
Logos-Quran-40
Logos-Quran-39
Logos-Quran-38
Logos-3D-38
Logos-3D-40
Logos-Alphabets-50
Logos-Alphabets-51
```

## Project Structure

```text
LogoMakerMac/
├── LogoMakerMacApp.swift
├── Theme/
│   └── AppTheme.swift
├── Models/
│   └── TemplateModels.swift
├── Services/
│   ├── AppStore.swift
│   ├── FavouritesStore.swift
│   └── TemplateService.swift
├── Views/
│   ├── RootView.swift
│   ├── SidebarView.swift
│   ├── HomeView.swift
│   ├── SearchView.swift
│   ├── TemplateGalleryView.swift
│   ├── CreateView.swift
│   ├── FavouritesView.swift
│   └── CommonViews.swift
├── SVGEditor/
│   ├── Models/
│   │   └── SVGModels.swift
│   ├── Parsing/
│   │   ├── SVGParser.swift
│   │   └── SVGTransformParser.swift
│   ├── Rendering/
│   │   ├── SVGCanvasRepresentable.swift
│   │   ├── SVGCanvasView.swift
│   │   └── SVGPathParser.swift
│   ├── Store/
│   │   └── SVGEditorStore.swift
│   ├── Views/
│   │   ├── SVGEditorView.swift
│   │   ├── LayersPanel.swift
│   │   └── InspectorPanel.swift
│   └── Resources/
│       └── *.svg
├── Assets.xcassets/
└── Resources/
    └── NewLogoMakerIOS-decoded.json
```

## Requirements

- macOS **13.0+**
- Xcode with macOS 13 SDK support or newer
- Swift **5**
- No third-party Swift package dependencies in the current project

## Getting Started

1. Clone the repository:

   ```bash
   git clone https://github.com/KaleemAshraf514/LogoMakerMac.git
   ```

2. Open the Xcode project:

   ```bash
   cd LogoMakerMac
   open LogoMakerMac.xcodeproj
   ```

3. Select the **LogoMakerMac** scheme.
4. Choose **My Mac** as the run destination.
5. Build and run with **⌘R**.

## Design

The app uses a shared Logo Maker theme throughout the main interface and SVG editor. The primary brand gradient runs from purple `#7B2FF7` to pink `#F02FC2`, with shared card, background, separator, and text styling defined in `AppTheme`.

## Current Scope

The repository focuses on the macOS template experience and native SVG editing/export pipeline. The **PRO subscription** and broader **AI Logo Maker** workflow are currently represented as under-development UI rather than completed production services.

## Tech Stack

**SwiftUI · AppKit · Core Graphics · Core Animation · Foundation · XMLParser**

---

Built as a native macOS SwiftUI project with an editable SVG rendering pipeline.
