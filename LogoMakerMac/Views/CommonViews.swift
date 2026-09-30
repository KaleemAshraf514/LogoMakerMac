import SwiftUI

struct RemoteTemplateImage: View {
    let url: URL?
    var aspectRatio: Double = 1

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            case .failure:
                placeholder(systemName: "photo.badge.exclamationmark")
            case .empty:
                ZStack { Color.secondary.opacity(0.08); ProgressView().controlSize(.small) }
            @unknown default:
                placeholder(systemName: "photo")
            }
        }
        .aspectRatio(1 / max(0.2, aspectRatio), contentMode: .fit)
        .clipped()
    }

    private func placeholder(systemName: String) -> some View {
        ZStack { Color.secondary.opacity(0.08); Image(systemName: systemName).foregroundStyle(.secondary) }
    }
}

struct HeartButton: View {
    let isFavourite: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isFavourite ? "heart.fill" : "heart")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isFavourite ? AppTheme.activeHeart : Color.secondary)
                .padding(7)
                .background(.regularMaterial, in: Circle())
        }
        .buttonStyle(.plain)
    }
}

struct UnderDevelopmentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.78 : 1)
    }
}


// A macOS-friendly wrapping layout for chips/tags.
// Items keep their natural width and automatically move to the next row
// when the window becomes narrower.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    struct CacheData {
        var sizes: [CGSize] = []
    }

    func makeCache(subviews: Subviews) -> CacheData {
        CacheData(sizes: subviews.map { $0.sizeThatFits(.unspecified) })
    }

    func updateCache(_ cache: inout CacheData, subviews: Subviews) {
        cache.sizes = subviews.map { $0.sizeThatFits(.unspecified) }
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout CacheData
    ) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var usedWidth: CGFloat = 0

        for size in cache.sizes {
            if x > 0 && x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }

            usedWidth = max(usedWidth, x + size.width)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(width: min(usedWidth, maxWidth), height: y + rowHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout CacheData
    ) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for (index, subview) in subviews.enumerated() {
            let size = cache.sizes[index]

            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }

            subview.place(
                at: CGPoint(x: x, y: y),
                anchor: .topLeading,
                proposal: ProposedViewSize(size)
            )

            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
