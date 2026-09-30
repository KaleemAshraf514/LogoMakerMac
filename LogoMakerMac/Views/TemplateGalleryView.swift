import SwiftUI

struct TemplateGalleryView: View {
    let category: TemplateCategory
    let subcategory: TemplateSubCategory
    @EnvironmentObject private var favourites: FavouritesStore
    @State private var selectedTemplate: URL?

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 220), spacing: 16)], spacing: 16) {
                ForEach(subcategory.templateThumbnailURLs, id: \.absoluteString) { url in
                    ZStack(alignment: .topTrailing) {
                        Button { selectedTemplate = url } label: {
                            RemoteTemplateImage(url: url, aspectRatio: category.aspectRatioHeightOverWidth)
                                .background(AppTheme.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.separator))
                        }.buttonStyle(.plain)
                        HeartButton(isFavourite: favourites.isTemplateFavourite(url)) { favourites.toggleTemplate(url) }
                            .padding(8)
                    }
                }
            }.padding(24)
        }
        .navigationTitle(subcategory.Subcategory_DisplayName)
        .background(AppTheme.screenBackground)
        .alert("Canvas Under Development", isPresented: Binding(
            get: { selectedTemplate != nil }, set: { if !$0 { selectedTemplate = nil } }
        )) {
            Button("OK", role: .cancel) { selectedTemplate = nil }
        } message: {
            Text("Template selected successfully. The editor canvas will be added later.")
        }
    }
}
