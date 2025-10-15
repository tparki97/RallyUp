import SwiftUI

enum Theme {
    // Brand palette
    static let teal   = Color(hex: "#14B8A6") // Primary
    static let coral  = Color(hex: "#FF6B6B") // Accent
    static let sun    = Color(hex: "#FDE047")
    static let ink    = Color(hex: "#1F2937")
    static let cardLight = Color(hex: "#F9FAFB")
    static let cardDark  = Color(hex: "#0B1220")

    // Common style tokens
    static let cornerRadius: CGFloat = 14
    static let shadow = ShadowStyle(radius: 10, y: 4, opacity: 0.08)

    struct ShadowStyle {
        let radius: CGFloat; let y: CGFloat; let opacity: Double
    }
}
