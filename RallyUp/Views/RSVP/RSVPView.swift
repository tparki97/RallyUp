import SwiftUI

struct RSVPView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm: RSVPViewModel

    init(partyId: String) {
        _vm = StateObject(wrappedValue: RSVPViewModel(partyId: partyId))
    }

    var body: some View {
        Form {
            Section("Your RSVP") {
                Picker("Status", selection: $vm.status) {
                    ForEach(RSVPStatus.allCases) { s in
                        Text(s.label).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("RSVP status")

                Stepper(value: $vm.partySize, in: 1...20, step: 1) {
                    HStack {
                        Text("Party size")
                        Spacer()
                        Text("\(vm.status == .no ? 0 : vm.partySize)")
                            .accessibilityLabel("Party size \(vm.partySize)")
                    }
                }
                .disabled(vm.status == .no)

                TextField("Notes (dietary needs, etc.)", text: $vm.notes, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
            }

            Section("Headcount") {
                HStack { Text("Yes"); Spacer(); Text("\(vm.summary.yesCount)") }
                HStack { Text("Maybe"); Spacer(); Text("\(vm.summary.maybeCount)") }
                HStack { Text("No"); Spacer(); Text("\(vm.summary.noCount)") }
                HStack {
                    Text("Total coming")
                    Spacer()
                    Text("\(vm.summary.headcountYes)")
                        .fontWeight(.semibold)
                }
            }

            Section {
                Button {
                    Task {
                        await vm.save()
                        dismiss()
                    }
                } label: {
                    Text("Save RSVP").frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.teal)
            }
        }
        .navigationTitle("RSVP")
        .onAppear { vm.start() }
        .onDisappear { vm.stop() }
    }
}

#Preview {
    NavigationStack { RSVPView(partyId: "demo") }
}
