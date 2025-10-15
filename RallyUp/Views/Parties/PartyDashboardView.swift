import SwiftUI

struct PartyDashboardView: View {
    let partyId: String
    @State private var party: Party?
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let p = party {
                    Text(p.title)
                        .font(.largeTitle.bold())

                    if let date = p.startAt {
                        Text(date.formatted(date: .abbreviated, time: .shortened))
                            .foregroundStyle(.secondary)
                    }

                    GroupBox {
                        NavigationLink {
                            RSVPView(partyId: p.id)
                        } label: {
                            Label("Respond / Edit RSVP", systemImage: "checkmark.circle.fill")
                                .font(.headline)
                        }
                    } label: {
                        Label("RSVP", systemImage: "checkmark.circle")
                    }

                    GroupBox {
                        NavigationLink {
                            PollsListView(partyId: p.id)
                        } label: {
                            Label("Open Polls", systemImage: "checklist")
                                .font(.headline)
                        }
                    } label: {
                        Label("Polls", systemImage: "list.bullet.rectangle")
                    }

                    GroupBox {
                        VStack(spacing: 12) {
                            Text("Join code: \(p.joinCode)")
                                .font(.title3.monospaced())
                                .accessibilityLabel("Join code \(p.joinCode)")
                            QRCodeView(text: p.joinCode)
                                .frame(height: 180)
                            ShareLink(item: "RallyUp code: \(p.joinCode)\n\nOpen the app, tap Join, and enter this code.") {
                                Label("Share code", systemImage: "square.and.arrow.up")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    } label: {
                        Label("Invite", systemImage: "qrcode")
                    }

                    GroupBox {
                        Text("Tasks, Gallery and Chat are coming here.")
                            .foregroundStyle(.secondary)
                    } label: {
                        Label("Next", systemImage: "sparkles")
                    }
                } else if isLoading {
                    ProgressView()
                } else {
                    Text("Party not found.")
                }
            }
            .padding()
        }
        .navigationTitle("Party")
        .task {
            isLoading = true
            party = try? await FirestoreService.shared.fetchParty(partyId: partyId)
            isLoading = false
        }
    }
}

#Preview {
    NavigationStack { PartyDashboardView(partyId: "demo") }
}
