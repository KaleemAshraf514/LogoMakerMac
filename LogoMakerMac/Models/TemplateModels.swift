import Foundation

struct TemplatesResponse: Codable {
    let AppData: AppDataContent
}

struct AppDataContent: Codable {
    let AppVersion: String
    let Templates: [TemplatesVersionBlock]
}

struct TemplatesVersionBlock: Codable {
    let TemplatesVersion: String
    let Categories: [TemplateCategory]
}

struct TemplateCategory: Codable, Identifiable, Hashable {
    let Category_Display_Name: String
    let Category_S3_Name: String
    let Category_Aspect_Ratio: String
    let Category_Index: Int
    let Free_Templates: Int
    let isDoubleSided: Bool
    let Category_Color: [String]?
    let Category_Free: Bool
    let SubCategories: [TemplateSubCategory]

    var id: String { Category_S3_Name }

    var isVisibleInTemplateBrowser: Bool {
        let hidden: Set<String> = ["stickers", "shapes"]
        return !hidden.contains(Category_Display_Name.trimmedLower) &&
               !hidden.contains(Category_S3_Name.trimmedLower)
    }

    var iconAssetName: String? {
        let display = Category_Display_Name.trimmedLower
        let s3 = Category_S3_Name.trimmedLower
        switch (display, s3) {
        case ("logos", _), (_, "logos"): return "CategoryLogo"
        case ("flyers", _), (_, "flyers"): return "CategoryFlyers"
        case ("posters", _), (_, "posters"): return "CategoryPoster"
        case ("business cards", _), (_, "businesscard"): return "CategoryBusinessCards"
        case ("invitations", _), (_, "invitations"): return "CategoryInvitation"
        case ("instagram story", _), ("ig story", _), (_, "instagramstory"), (_, "igstory"): return "CategoryIGStory"
        default: return nil
        }
    }

    var selectedIconAssetName: String? {
        iconAssetName.map { "\($0)Selected" }
    }

    var aspectRatioHeightOverWidth: Double {
        let parts = Category_Aspect_Ratio.split(separator: ":")
        guard parts.count == 2,
              let w = Double(parts[0]), let h = Double(parts[1]), w > 0, h > 0 else { return 1 }
        return h / w
    }
}

struct TemplateSubCategory: Codable, Identifiable, Hashable {
    let Subcategory_DisplayName: String
    let Subcategory_S3_Name: String
    let Subcategory_Item_Count: Int
    let SubCategory_Index: Int
    let isNew: Bool?
    let Subcategory_Free_Templates: Int?
    let Subcategory_Free: Bool?
    let Subcategory_Thumbnail_URL: String?

    var id: String { "\(Subcategory_S3_Name)-\(SubCategory_Index)" }

    var templateThumbnailURLs: [URL] {
        guard Subcategory_Item_Count > 0,
              let first = Subcategory_Thumbnail_URL,
              let marker = first.range(of: "-1.", options: .backwards) else {
            if let first = Subcategory_Thumbnail_URL, let url = URL(string: first) { return [url] }
            return []
        }
        let prefix = String(first[..<marker.lowerBound])
        let suffix = String(first[marker.lowerBound...]).dropFirst(2)
        return (1...Subcategory_Item_Count).compactMap { URL(string: "\(prefix)-\($0)\(suffix)") }
    }
}

private extension String {
    var trimmedLower: String {
        trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
