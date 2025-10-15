import SwiftUI

struct CreatePartyView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = PartiesViewModel()
    @State private var title = ""
    @State private var date = Date()

    let onDone: () -> Void

    var body: some View {
        Form {
            Section("Details") {
                TextField("Party title", text: $title)
                    .textInputAutocapitalization(.words)
                DatePicker("Start", selection: $date, displayedComponents: [.date, .hourAndMinute])
            }

            Section {
                Button {
                    Task {
                        await vm.createParty(title: title.trimmingCharacters(in: .whitespaces), date: date)
                        onDone()
                        dismiss()
                    }
                } label: {
                    Text("Create Party")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .navigationTitle("Create Party")
    }
}

#Preview { NavigationStack { CreatePartyView(onDone: {}) } }
