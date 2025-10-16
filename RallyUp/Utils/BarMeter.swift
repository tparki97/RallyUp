import SwiftUI

struct BarMeter: View {
    let fraction: Double // 0...1 (we'll sanitize)

    // Force finite 0...1
    private var safeFraction: Double {
        guard fraction.isFinite else { return 0 }
        return max(0, min(1, fraction))
    }

    var body: some View {
        GeometryReader { geo in
            // Make sure width we feed to CoreGraphics is finite & non-negative
            let containerW = Double(geo.size.width)
            let widthDouble = (containerW.isFinite ? containerW : 0) * safeFraction
            let safeWidth = CGFloat(widthDouble.isFinite ? max(0, widthDouble) : 0)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.systemGray5))
                RoundedRectangle(cornerRadius: 6)
                    .fill(Theme.teal.opacity(0.65))
                    .frame(width: safeWidth)
            }
        }
        .frame(height: 10)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .accessibilityLabel("Bar meter")
        .accessibilityValue("\(Int((safeFraction * 100).rounded())) percent")
    }
}

#Preview { BarMeter(fraction: 0.6).padding() }
