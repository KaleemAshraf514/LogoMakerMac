import SwiftUI

struct FavouritesView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var favourites: FavouritesStore
    @State private var selectedTemplate: URL?

    private struct FavouriteTemplate: Identifiable {
        let category: TemplateCategory
        let subcategory: TemplateSubCategory
        let url: URL
        var id: String { url.absoluteString }
    }

    private struct FavouriteSubcategory: Identifiable {
        let category: TemplateCategory
        let subcategory: TemplateSubCategory
        var id: String { "\(category.id)::\(subcategory.id)" }
    }

    private var templates: [FavouriteTemplate] {
        store.categories.flatMap { category in
            category.SubCategories.flatMap { sub in
                sub.templateThumbnailURLs.compactMap { url in
                    favourites.isTemplateFavourite(url) ? FavouriteTemplate(category: category, subcategory: sub, url: url) : nil
                }
            }
        }
    }

    // Keep the number of columns stable while the sidebar animates.
    // Adaptive grids change column count mid-animation, which causes the
    // cards to snap smaller/larger. Flexible fixed columns resize smoothly.
    private let gridColumns: [GridItem] = Array(
        repeating: GridItem(.flexible(minimum: 120, maximum: 220), spacing: 16),
        count: 5
    )

    private var subcategories: [FavouriteSubcategory] {
        store.categories.flatMap { category in
            category.SubCategories.compactMap { sub in
                favourites.isSubcategoryFavourite(sub, in: category) ? FavouriteSubcategory(category: category, subcategory: sub) : nil
            }
        }
    }

    var body: some View {
        Group {
            if templates.isEmpty && subcategories.isEmpty {
                EmptyStateView(title: "No Favourites Yet", systemImage: "heart", message: "Tap the heart on any template to keep it here.")
            } else {
                ScrollView {
                    LazyVGrid(columns: gridColumns, spacing: 16) {
                        ForEach(templates) { item in
                            ZStack(alignment: .topTrailing) {
                                Button { selectedTemplate = item.url } label: {
                                    RemoteTemplateImage(url: item.url, aspectRatio: item.category.aspectRatioHeightOverWidth)
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.separator))
                                }.buttonStyle(.plain)
                                HeartButton(isFavourite: true) { favourites.removeTemplate(item.url) }.padding(8)
                            }
                        }

                        ForEach(subcategories) { item in
                            Button {
                                store.route.append(.gallery(category: item.category, subcategory: item.subcategory))
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    RemoteTemplateImage(url: item.subcategory.templateThumbnailURLs.first,
                                                        aspectRatio: item.category.aspectRatioHeightOverWidth)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    HStack {
                                        Text(item.subcategory.Subcategory_DisplayName).font(.subheadline.bold()).lineLimit(1)
                                        Spacer()
                                        Image(systemName: "heart.fill").foregroundStyle(AppTheme.activeHeart)
                                    }
                                }
                                .padding(10).background(RoundedRectangle(cornerRadius: 14).fill(AppTheme.cardBackground))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.separator))
                            }.buttonStyle(.plain)
                        }
                    }.padding(24)
                }
            }
        }
        .navigationTitle("Favourites")
        .background(AppTheme.screenBackground)
        .alert("Canvas Under Development", isPresented: Binding(
            get: { selectedTemplate != nil }, set: { if !$0 { selectedTemplate = nil } }
        )) {
            Button("OK", role: .cancel) { selectedTemplate = nil }
        } message: { Text("The editor canvas will be added later.") }
    }
}
