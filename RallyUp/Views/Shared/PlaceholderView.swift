import SwiftUI

struct PlaceholderView: View {
    let title: String
    var note: String? = nil

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.title2.bold())

            if let note {
                Text(note)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(Color(.systemGroupedBackground))
    }
}

#Preview {
    PlaceholderView(title: "Coming soon", note: "This section will arrive in a later step.")
}
