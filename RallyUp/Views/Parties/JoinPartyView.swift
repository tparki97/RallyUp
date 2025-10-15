import SwiftUI

struct JoinPartyView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = PartiesViewModel()
    @State private var code: String = ""
    let onResult: (FirestoreService.JoinResult?) -> Void

    var body: some View {
        Form {
            Section("Join Code") {
                TextField("ABC123", text: $code)
                    .textInputAutocapitalization(.characters)
                    .onChange(of: code) { code = code.uppercased() }
            }
            Section {
                Button("Join") {
                    Task {
                        let result = await vm.join(code: code)
                        onResult(result)
                        dismiss()
                    }
                }.disabled(code.trimmingCharacters(in: .whitespaces).count < 4)
            }
        }
        .navigationTitle("Join Party")
    }
}

#Preview { NavigationStack { JoinPartyView { _ in } } }
