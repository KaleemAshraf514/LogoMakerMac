import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @State private var isSidebarVisible = false

    private let sidebarWidth: CGFloat = 255

    var body: some View {
        HStack(spacing: 0) {
            ZStack(alignment: .leading) {
                SidebarView()
                    .frame(width: sidebarWidth)
                    .frame(maxHeight: .infinity)
                    .background(AppTheme.cardBackground)
                    .overlay(alignment: .trailing) {
                        Rectangle()
                            .fill(AppTheme.separator)
                            .frame(width: 1)
                    }
                    .offset(x: isSidebarVisible ? 0 : -sidebarWidth)
                    .opacity(isSidebarVisible ? 1 : 0.98)
            }
            .frame(width: isSidebarVisible ? sidebarWidth : 0, alignment: .leading)
            .clipped()

            NavigationStack(path: $store.route) {
                Group {
                    switch store.selectedSection {
                    case .home: HomeView()
                    case .create: CreateView()
                    case .favourites: FavouritesView()
                    }
                }
                .navigationDestination(for: AppStore.AppRoute.self) { route in
                    switch route {
                    case .search:
                        SearchView()
                    case .gallery(let category, let subcategory):
                        TemplateGalleryView(category: category, subcategory: subcategory)
                    case .svgEditor(let fileName):
                        SVGEditorView(initialFileName: fileName)
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .navigation) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.28)) {
                                isSidebarVisible.toggle()
                            }
                        } label: {
                            Image(systemName: "sidebar.left")
                        }
                        .help(isSidebarVisible ? "Hide Sidebar" : "Show Sidebar")
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
        .animation(.easeInOut(duration: 0.28), value: isSidebarVisible)
        .background(AppTheme.screenBackground)
    }
}
