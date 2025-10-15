import SwiftUI
import FirebaseAuth

struct MyPartiesView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = PartiesViewModel()
    @EnvironmentObject var auth: AuthService
    @State private var showCreate = false
    @State private var showJoin = false
    @State private var alertMsg: String?

    var body: some View {
        List {
            Section {
                Button {
                    showCreate = true
                } label: {
                    Label("Create Party", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .tint(Theme.teal)
                }

                Button {
                    showJoin = true
                } label: {
                    Label("Join by Code", systemImage: "qrcode")
                        .font(.headline)
                }
            }

            Section("My Parties") {
                if vm.parties.isEmpty {
                    Text("No parties yet. Create or join one!")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(vm.parties) { p in
                        NavigationLink {
                            PartyDashboardView(partyId: p.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(p.title).font(.headline)
                                HStack(spacing: 8) {
                                    Text(p.role.rawValue.capitalized)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Theme.cardLight)
                                        .clipShape(Capsule())
                                    if let date = p.startAt {
                                        Text(date.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("My Parties")
        .onAppear {
            if let uid = Auth.auth().currentUser?.uid { vm.start(uid: uid) }
        }
        .onDisappear { vm.stop() }
        .sheet(isPresented: $showCreate) {
            NavigationStack { CreatePartyView(onDone: { showCreate = false }) }
        }
        .sheet(isPresented: $showJoin) {
            NavigationStack {
                JoinPartyView { result in
                    showJoin = false
                    switch result {
                    case .joined(let p): alertMsg = "Joined \(p.title)!"
                    case .alreadyMember(let p): alertMsg = "You're already a member of \(p.title)."
                    case .notFound: alertMsg = "Code not found. Check and try again."
                    case .none: break
                    }
                }
            }
        }
        .alert("Info", isPresented: Binding(get: { alertMsg != nil }, set: { if !$0 { alertMsg = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMsg ?? "")
        }
    }
}

#Preview { MyPartiesView().environmentObject(AuthService()) }
