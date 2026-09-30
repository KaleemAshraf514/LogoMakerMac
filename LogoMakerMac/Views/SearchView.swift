import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var favourites: FavouritesStore
    @State private var query = ""
    @FocusState private var focused: Bool

    private struct SearchResult: Identifiable {
        let category: TemplateCategory
        let subcategory: TemplateSubCategory
        var id: String { "\(category.id)::\(subcategory.id)" }
    }

    private var results: [SearchResult] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return [] }
        return store.categories.flatMap { category in
            category.SubCategories.compactMap { sub in
                category.Category_Display_Name.localizedCaseInsensitiveContains(text) ||
                sub.Subcategory_DisplayName.localizedCaseInsensitiveContains(text)
                ? SearchResult(category: category, subcategory: sub) : nil
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search templates", text: $query)
                    .textFieldStyle(.plain).focused($focused)
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(AppTheme.cardBackground))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.separator))
            .padding(20)

            if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                EmptyStateView(title: "Search Templates", systemImage: "magnifyingglass", message: "Start typing a category or subcategory name.")
            } else if results.isEmpty {
                EmptyStateView(title: "No Templates Found", systemImage: "magnifyingglass", message: "No results for “\(query)”.")
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 190, maximum: 260), spacing: 16)], spacing: 16) {
                        ForEach(results) { result in
                            Button {
                                store.route.append(.gallery(category: result.category, subcategory: result.subcategory))
                            } label: {
                                VStack(alignment: .leading, spacing: 10) {
                                    ZStack(alignment: .topTrailing) {
                                        RemoteTemplateImage(url: result.subcategory.templateThumbnailURLs.first,
                                                            aspectRatio: result.category.aspectRatioHeightOverWidth)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                        HeartButton(isFavourite: favourites.isSubcategoryFavourite(result.subcategory, in: result.category)) {
                                            favourites.toggleSubcategory(result.subcategory, in: result.category)
                                        }.padding(6)
                                    }
                                    Text(result.subcategory.Subcategory_DisplayName).font(.headline).lineLimit(1)
                                    Text(result.category.Category_Display_Name).font(.caption).foregroundStyle(.secondary)
                                }
                                .padding(10)
                                .background(RoundedRectangle(cornerRadius: 14).fill(AppTheme.cardBackground))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.separator))
                            }.buttonStyle(.plain)
                        }
                    }.padding(20)
                }
            }
            Spacer(minLength: 0)
        }
        .navigationTitle("Search")
        .background(AppTheme.screenBackground)
        .onAppear { focused = true }
    }
}
