import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            NavigationStack { HomeView() }
                .tabItem { Label("Home", systemImage: "house.fill") }

            // Polls are per-party. Route to MyParties, then into a party -> Polls.
            NavigationStack { MyPartiesView() }
                .tabItem { Label("Polls", systemImage: "checklist") }

            NavigationStack { TasksView() }
                .tabItem { Label("Tasks", systemImage: "square.and.pencil") }

            NavigationStack { GalleryView() }
                .tabItem { Label("Gallery", systemImage: "photo.on.rectangle") }

            NavigationStack { ChatView() }
                .tabItem { Label("Chat", systemImage: "bubble.left.and.bubble.right.fill") }

            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(Theme.teal) // Brand color for selected tab and controls
        .accessibilityLabel("RallyUp main tabs")
    }
}

#Preview { ContentView() }
