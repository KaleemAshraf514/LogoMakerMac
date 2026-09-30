import Foundation

final class TemplateService {
    static let shared = TemplateService()
    private init() {}

    func loadCategories() throws -> [TemplateCategory] {
        guard let url = Bundle.main.url(forResource: "NewLogoMakerIOS-decoded", withExtension: "json") else {
            throw NSError(domain: "TemplateService", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Template data is missing from the app bundle."])
        }
        let data = try Data(contentsOf: url)
        let response = try JSONDecoder().decode(TemplatesResponse.self, from: data)
        guard let block = response.AppData.Templates.first else {
            throw NSError(domain: "TemplateService", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "No template catalogue block was found."])
        }
        return block.Categories
            .filter(\.isVisibleInTemplateBrowser)
            .sorted { $0.Category_Index < $1.Category_Index }
    }
}
