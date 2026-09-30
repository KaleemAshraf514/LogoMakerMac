import SwiftUI

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r, g, b: UInt64
        switch cleaned.count {
        case 3:
            (r, g, b) = ((value >> 8) * 17, (value >> 4 & 0xF) * 17, (value & 0xF) * 17)
        default:
            (r, g, b) = (value >> 16, value >> 8 & 0xFF, value & 0xFF)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: 1)
    }
}

enum AppTheme {
    static let gradientStart = Color(hex: "#7B2FF7")
    static let gradientEnd = Color(hex: "#F02FC2")
    static let headerGradientEnd = Color(hex: "#A855F7")
    static let activeHeart = Color(hex: "#FF3B5C")
    static let newBadge = Color(hex: "#28C76F")
    static let upgradeOrange = Color(hex: "#FFA800")

    static let brandGradient = LinearGradient(
        colors: [gradientStart, gradientEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let headerGradient = LinearGradient(
        colors: [gradientStart, headerGradientEnd],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let screenBackground = Color(nsColor: .windowBackgroundColor)
    static let cardBackground = Color(nsColor: .controlBackgroundColor)
    static let primaryText = Color.primary
    static let secondaryText = Color.secondary
    static let separator = Color(nsColor: .separatorColor)
}
