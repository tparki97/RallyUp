import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct PollsListView: View {
    let partyId: String

    @State private var polls: [PollItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    @State private var canManage = false
    @State private var showCreate = false

    @State private var listener: ListenerRegistration? = nil

    // ✅ Explicit, non-private init so other views can construct this.
    init(partyId: String) {
        self.partyId = partyId
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .opacity(0)
                Text("Polls")
                    .font(.largeTitle.bold())
                Spacer()
                if canManage {
                    Button {
                        showCreate = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .accessibilityLabel("Create poll")
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)

            content
        }
        .onAppear {
            startListening()
            checkManagePermission()
        }
        .onDisappear {
            stopListening()
        }
        .sheet(isPresented: $showCreate) {
            NavigationStack { CreatePollView(partyId: partyId) }
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else if let msg = errorMessage {
            VStack(spacing: 16) {
                Text("Couldn’t load polls").font(.title3).bold()
                Text(msg)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(6)
                Button("Try again") { restartListening() }
                    .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding()
        } else if polls.isEmpty {
            VStack(spacing: 8) {
                Text("No polls yet").foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else {
            List(polls) { item in
                NavigationLink(destination: VotePollView(partyId: partyId, pollId: item.id)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.question).font(.body)
                        HStack(spacing: 8) {
                            Text(item.typeDisplay).font(.caption).foregroundStyle(.secondary)
                            if item.isLocked { Image(systemName: "lock.fill").font(.caption2) }
                            Spacer()
                            Text(item.createdAt, style: .date)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .listStyle(.plain)
        }
    }

    // MARK: - Live listeners

    private func startListening() {
        if listener != nil { return }
        isLoading = true
        errorMessage = nil
        polls.removeAll()

        let q = Firestore.firestore()
            .collection("parties").document(partyId)
            .collection("polls")
            .order(by: "createdAt", descending: true)

        listener = q.addSnapshotListener { snap, err in
            if let err {
                errorMessage = err.localizedDescription
                isLoading = false
                return
            }
            let docs = snap?.documents ?? []
            let mapped = docs.compactMap { self.mapPoll(doc: $0) }
            DispatchQueue.main.async {
                self.polls = mapped
                self.isLoading = false
            }
        }
    }

    private func stopListening() {
        listener?.remove()
        listener = nil
    }

    private func restartListening() {
        stopListening()
        startListening()
    }

    // MARK: - Helpers

    private func mapPoll(doc: QueryDocumentSnapshot) -> PollItem? {
        let data = doc.data()
        return PollItem(
            id: doc.documentID,
            question: (data["question"] as? String) ?? "",
            typeRaw: (data["type"] as? String) ?? "single",
            isLocked: (data["isLocked"] as? Bool) ?? false,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? .distantPast
        )
    }

    /// Owner or admin can manage polls. Reads from root party doc per our rules.
    private func checkManagePermission() {
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else { return }
        Firestore.firestore()
            .collection("parties").document(partyId)
            .addSnapshotListener { snap, _ in
                let data = snap?.data() ?? [:]
                let owner = (data["ownerId"] as? String) ?? (data["createdBy"] as? String) ?? ""
                let admins = (data["admins"] as? [String: Bool]) ?? [:]
                canManage = (uid == owner) || (admins[uid] == true)
            }
    }
}

struct PollItem: Identifiable {
    let id: String
    let question: String
    let typeRaw: String
    let isLocked: Bool
    let createdAt: Date

    var typeDisplay: String {
        switch typeRaw.lowercased() {
        case "ranked": return "Ranked"
        case "multiple", "multiplechoice", "multi": return "Multiple choice"
        default: return "Single choice"
        }
    }
}
