import Foundation

@MainActor
final class FavouritesStore: ObservableObject {
    @Published private(set) var templateURLs: Set<String>
    @Published private(set) var subcategoryIDs: Set<String>

    private let templateKey = "com.logomaker.favouriteTemplateURLs.v1"
    private let subcategoryKey = "com.logomaker.favouriteTemplateIDs.v2"

    init() {
        templateURLs = Set(UserDefaults.standard.stringArray(forKey: templateKey) ?? [])
        subcategoryIDs = Set(UserDefaults.standard.stringArray(forKey: subcategoryKey) ?? [])
    }

    func isTemplateFavourite(_ url: URL) -> Bool { templateURLs.contains(url.absoluteString) }

    func toggleTemplate(_ url: URL) {
        let id = url.absoluteString
        if templateURLs.contains(id) { templateURLs.remove(id) } else { templateURLs.insert(id) }
        persist()
    }

    func removeTemplate(_ url: URL) {
        templateURLs.remove(url.absoluteString)
        persist()
    }

    func stableID(category: TemplateCategory, subcategory: TemplateSubCategory) -> String {
        "\(category.Category_S3_Name)::\(subcategory.Subcategory_S3_Name)"
    }

    func isSubcategoryFavourite(_ subcategory: TemplateSubCategory, in category: TemplateCategory) -> Bool {
        subcategoryIDs.contains(stableID(category: category, subcategory: subcategory))
    }

    func toggleSubcategory(_ subcategory: TemplateSubCategory, in category: TemplateCategory) {
        let id = stableID(category: category, subcategory: subcategory)
        if subcategoryIDs.contains(id) { subcategoryIDs.remove(id) } else { subcategoryIDs.insert(id) }
        persist()
    }

    private func persist() {
        UserDefaults.standard.set(Array(templateURLs).sorted(), forKey: templateKey)
        UserDefaults.standard.set(Array(subcategoryIDs).sorted(), forKey: subcategoryKey)
    }
}
