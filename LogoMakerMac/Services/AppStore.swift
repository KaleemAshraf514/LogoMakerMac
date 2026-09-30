import Foundation

@MainActor
final class AppStore: ObservableObject {
    @Published var categories: [TemplateCategory] = []
    @Published var selectedCategoryID: String?
    @Published var selectedSection: AppSection = .home
    @Published var route: [AppRoute] = []
    @Published var loadError: String?

    enum AppSection: String, CaseIterable, Identifiable {
        case home = "Home"
        case create = "Create"
        case favourites = "Favourites"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .create: return "plus.square.fill"
            case .favourites: return "heart.fill"
            }
        }
    }

    enum AppRoute: Hashable {
        case search
        case gallery(category: TemplateCategory, subcategory: TemplateSubCategory)
        case svgEditor(fileName: String)
    }

    init() { reload() }

    func reload() {
        do {
            let loaded = try TemplateService.shared.loadCategories()
            categories = loaded
            selectedCategoryID = loaded.first(where: {
                $0.Category_Display_Name.caseInsensitiveCompare("Logos") == .orderedSame
            })?.id ?? loaded.first?.id
            loadError = nil
        } catch {
            categories = []
            loadError = error.localizedDescription
        }
    }

    var selectedCategory: TemplateCategory? {
        categories.first(where: { $0.id == selectedCategoryID }) ?? categories.first
    }
}
