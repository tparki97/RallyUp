import SwiftUI

struct HomeView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Welcome to RallyUp 🎉")
                    .font(.largeTitle.bold())
                    .accessibilityLabel("Welcome to RallyUp")

                Text("Create or join a party to get started.")
                    .font(.body)
                    .foregroundStyle(.secondary)

                NavigationLink {
                    MyPartiesView()
                } label: {
                    RoundedRectangle(cornerRadius: Theme.cornerRadius)
                        .fill(Color(uiColor: .secondarySystemBackground))
                        .frame(height: 120)
                        .overlay(
                            VStack(spacing: 8) {
                                Text("Parties")
                                    .font(.headline)
                                Text("Create • Join • Manage")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        )
                        .padding(.top, 8)
                }
                .buttonStyle(.plain)
            }
            .padding()
        }
        .navigationTitle("Home")
    }
}

#Preview { HomeView() }
