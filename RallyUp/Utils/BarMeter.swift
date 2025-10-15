import SwiftUI

struct BarMeter: View {
    let fraction: Double // 0...1

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.systemGray5))
                RoundedRectangle(cornerRadius: 6)
                    .fill(Theme.teal.opacity(0.65))
                    .frame(width: max(0, min(1, fraction)) * geo.size.width)
            }
        }
        .frame(height: 10)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

#Preview { BarMeter(fraction: 0.6).padding() }
