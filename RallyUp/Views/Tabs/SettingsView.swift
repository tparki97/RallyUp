import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var auth: AuthService
    @StateObject private var user = UserStore()

    var body: some View {
        Form {
            Section("Profile") {
                TextField("Display name", text: $user.displayName)
                    .textInputAutocapitalization(.words)
                    .disableAutocorrection(true)
            }
            Section("Session") {
                HStack {
                    Text("User ID")
                    Spacer()
                    Text(auth.uid ?? "–")
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .accessibilityLabel("User I D")
                }
                Button("Sign out (anonymous)") {
                    auth.signOut()
                }
                .foregroundStyle(.red)
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    SettingsView().environmentObject(AuthService())
}
