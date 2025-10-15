import SwiftUI

extension Color {
    /// Supports Color(hex: "#RRGGBB") and Color("#RRGGBB")
    public init(hex: String) {
        self.init(_hexString: hex)
    }

    /// Unlabeled variant for existing call sites like `Color("#RRGGBB")`
    public init(_ hex: String) {
        self.init(_hexString: hex)
    }

    /// Actual implementation
    private init(_hexString: String) {
        var hex = _hexString.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        hex = hex.uppercased()

        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch hex.count {
        case 6: // RRGGBB
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8: // AARRGGBB
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0) // default to black if malformed
        }

        self = Color(.sRGB,
                     red: Double(r) / 255.0,
                     green: Double(g) / 255.0,
                     blue: Double(b) / 255.0,
                     opacity: Double(a) / 255.0)
    }
}
