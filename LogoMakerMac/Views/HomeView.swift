import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var favourites: FavouritesStore
    @State private var selectedQuickAccessID: String? = nil
    @State private var showProAlert = false
    @State private var showSVGCanvasCategory = false

    private var category: TemplateCategory? { store.selectedCategory }
    private var sections: [TemplateSubCategory] {
        (category?.SubCategories ?? []).sorted { $0.SubCategory_Index < $1.SubCategory_Index }
    }
    private var visibleSections: [TemplateSubCategory] {
        guard let id = selectedQuickAccessID else { return sections }
        return sections.filter { $0.id == id }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                header
                categoryStrip
                aiBanner

                if showSVGCanvasCategory {
                    svgCanvasSection
                } else {
                    quickAccessStrip

                    if let error = store.loadError {
                        EmptyStateView(title: "Couldn't load templates", systemImage: "exclamationmark.triangle", message: error)
                            .frame(maxWidth: .infinity, minHeight: 300)
                        Button("Retry") { store.reload() }
                    } else {
                        ForEach(visibleSections) { subcategory in
                            sectionView(subcategory)
                        }
                    }
                }
            }
            .padding(26)
        }
        .background(AppTheme.screenBackground)
        .navigationTitle("Home")
        .alert("Under Development", isPresented: $showProAlert) {
            Button("OK", role: .cancel) { }
        } message: { Text("PRO subscription is under development.") }
        .onChange(of: store.selectedCategoryID) { _ in
            selectedQuickAccessID = nil
        }
    }

    private var header: some View {
        ZStack {
            // Keep the title visually centered regardless of the buttons on the right.
            VStack(spacing: 2) {
                Text("Logo Maker")
                    .font(.system(size: 28, weight: .bold))
                Text("Create your brand, one template at a time")
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)

            HStack {
                Spacer()

                Button { store.route.append(.search) } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.gradientStart)
                .background(Circle().fill(AppTheme.cardBackground))

                Button("PRO") { showProAlert = true }
                    .buttonStyle(.plain)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(AppTheme.gradientStart))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var categoryStrip: some View {
        GeometryReader { geometry in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 18) {
                    ForEach(store.categories) { item in
                        Button {
                            showSVGCanvasCategory = false
                            store.selectedCategoryID = item.id
                        } label: {
                            VStack(spacing: 8) {
                                if let name = (!showSVGCanvasCategory && item.id == store.selectedCategoryID) ? item.selectedIconAssetName : item.iconAssetName {
                                    Image(name)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 66, height: 66)
                                } else {
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(AppTheme.gradientStart.opacity(0.1))
                                        .frame(width: 66, height: 66)
                                        .overlay(Image(systemName: "square.grid.2x2"))
                                }

                                Text(item.Category_Display_Name)
                                    .font(.caption.weight((!showSVGCanvasCategory && item.id == store.selectedCategoryID) ? .bold : .medium))
                                    .foregroundStyle((!showSVGCanvasCategory && item.id == store.selectedCategoryID) ? AppTheme.gradientStart : AppTheme.primaryText)
                                    .lineLimit(1)
                            }
                            .frame(width: 104)
                        }
                        .buttonStyle(.plain)
                    }

                    // The current app only has seven editable SVG samples, so we
                    // expose them as one extra first-class category instead of
                    // pretending they belong to the remote JSON template catalog.
                    Button {
                        showSVGCanvasCategory = true
                        selectedQuickAccessID = nil
                    } label: {
                        VStack(spacing: 8) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(showSVGCanvasCategory ? AnyShapeStyle(AppTheme.brandGradient) : AnyShapeStyle(AppTheme.gradientStart.opacity(0.12)))
                                    .frame(width: 66, height: 66)
                                Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                                    .font(.system(size: 27, weight: .semibold))
                                    .foregroundStyle(showSVGCanvasCategory ? Color.white : AppTheme.gradientStart)
                            }

                            Text("SVG Canvas")
                                .font(.caption.weight(showSVGCanvasCategory ? .bold : .medium))
                                .foregroundStyle(showSVGCanvasCategory ? AppTheme.gradientStart : AppTheme.primaryText)
                                .lineLimit(1)
                        }
                        .frame(width: 104)
                    }
                    .buttonStyle(.plain)
                }
                // When all categories fit, they sit in the middle.
                // On a narrow window this becomes a normal horizontal scroll view.
                .frame(minWidth: geometry.size.width, alignment: .center)
            }
        }
        .frame(height: 98)
    }

    private var aiBanner: some View {
        Button {
            store.selectedSection = .create
            store.route.removeAll()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "wand.and.stars").font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI Logo Maker").font(.headline)
                    Text("Turn your idea into a logo").font(.caption).opacity(0.9)
                }
                Spacer()
                Image(systemName: "arrow.right.circle.fill").font(.title2)
            }
            .foregroundStyle(.white).padding(.horizontal, 20).frame(height: 76)
            .background(AppTheme.brandGradient, in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(UnderDevelopmentButtonStyle())
    }

    private var quickAccessStrip: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            HStack(spacing: 8) {
                chip(title: "All", selected: selectedQuickAccessID == nil) {
                    selectedQuickAccessID = nil
                }

                ForEach(sections) { sub in
                    chip(
                        title: sub.Subcategory_DisplayName,
                        selected: selectedQuickAccessID == sub.id
                    ) {
                        selectedQuickAccessID = sub.id
                    }
                }
            }
            .padding(.bottom, 6)
        }
    }

    private func chip(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.caption.weight(.semibold)).lineLimit(1)
                .foregroundStyle(selected ? .white : AppTheme.primaryText)
                .padding(.horizontal, 13).padding(.vertical, 8)
                .background(selected ? AnyShapeStyle(AppTheme.gradientStart) : AnyShapeStyle(AppTheme.cardBackground), in: Capsule())
                .overlay(Capsule().stroke(selected ? Color.clear : AppTheme.separator))
        }.buttonStyle(.plain)
    }

    private let svgFiles = [
        "Logos-Quran-40",
        "Logos-Quran-39",
        "Logos-Quran-38",
        "Logos-3D-38",
        "Logos-3D-40",
        "Logos-Alphabets-50",
        "Logos-Alphabets-51"
    ]

    /// Home preview for the bundled SVG templates.
    /// Clicking a card pushes the native SVG editor through NavigationStack, so
    /// the standard macOS Back button returns to Home automatically.
    private var svgCanvasSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SVG Canvas")
                        .font(.title3.bold())
                    Text("Choose a vector template to open the editable native canvas")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(svgFiles.count) SVGs")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.gradientStart)
            }

            ScrollView(.horizontal, showsIndicators: true) {
                LazyHStack(spacing: 14) {
                    ForEach(svgFiles, id: \.self) { fileName in
                        Button {
                            store.route.append(.svgEditor(fileName: fileName))
                        } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.white)

                                    Image("SVGPreview-\(fileName)")
                                        .resizable()
                                        .interpolation(.high)
                                        .scaledToFit()
                                        .padding(12)
                                }
                                .frame(width: 176, height: 176)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(AppTheme.separator)
                                )

                                HStack(spacing: 6) {
                                    Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                                        .foregroundStyle(AppTheme.gradientStart)
                                    Text(fileName.replacingOccurrences(of: "Logos-", with: ""))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppTheme.primaryText)
                                        .lineLimit(1)
                                }
                            }
                            .padding(10)
                            .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 18))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 7)
            }
        }
    }

    private func sectionView(_ subcategory: TemplateSubCategory) -> some View {
        TemplatePreviewSection(
            subcategory: subcategory,
            category: category
        )
    }

}

struct EmptyStateView: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.title3.bold())

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}


private struct TemplatePreviewSection: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var favourites: FavouritesStore

    let subcategory: TemplateSubCategory
    let category: TemplateCategory?

    private var urls: [URL] {
        subcategory.templateThumbnailURLs
    }

    private let cardWidth: CGFloat = 160

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                    Text(subcategory.Subcategory_DisplayName)
                        .font(.title3.bold())

                    if subcategory.isNew == true {
                        Text("NEW")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(AppTheme.newBadge))
                    }

                    Spacer()

                    Button("See All") {
                        if let category {
                            store.route.append(.gallery(category: category, subcategory: subcategory))
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.gradientStart)
                    .font(.subheadline.bold())
                }

                ScrollView(.horizontal, showsIndicators: true) {
                    LazyHStack(spacing: 14) {
                        ForEach(Array(urls.enumerated()), id: \.offset) { index, url in
                            templateCard(url: url)
                                .frame(width: cardWidth)
                                .id(index)
                        }
                    }
                    .padding(.bottom, 6)
                }
            }
        }

    private func templateCard(url: URL) -> some View {
        ZStack(alignment: .topTrailing) {
            Button {
                if let category {
                    store.route.append(.gallery(category: category, subcategory: subcategory))
                }
            } label: {
                RemoteTemplateImage(
                    url: url,
                    aspectRatio: category?.aspectRatioHeightOverWidth ?? 1
                )
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.separator.opacity(0.7)))
            }
            .buttonStyle(.plain)

            HeartButton(isFavourite: favourites.isTemplateFavourite(url)) {
                favourites.toggleTemplate(url)
            }
            .padding(7)
        }
    }
}
