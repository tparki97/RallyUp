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

    // Live listeners
    @State private var primaryListener: ListenerRegistration? = nil
    @State private var fallbackListener: ListenerRegistration? = nil
    @State private var usingFallbackQuery = false

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
        if primaryListener != nil || fallbackListener != nil { return }
        isLoading = true
        errorMessage = nil
        usingFallbackQuery = false
        polls.removeAll()

        let primaryQuery = Firestore.firestore()
            .collection("parties").document(partyId)
            .collection("polls")
            .order(by: "createdAt", descending: true)

        primaryListener = primaryQuery.addSnapshotListener { snap, err in
            if let err { errorMessage = err.localizedDescription; isLoading = false; return }
            let docs = snap?.documents ?? []
            if !docs.isEmpty {
                let mapped = docs.compactMap { self.mapPoll(doc: $0) }
                DispatchQueue.main.async {
                    self.polls = mapped
                    self.isLoading = false
                    self.usingFallbackQuery = false
                }
            } else {
                // Subcollection empty — also listen on fallback top-level (dev resilience)
                attachFallbackIfNeeded()
                DispatchQueue.main.async { self.isLoading = false }
            }
        }
    }

    private func attachFallbackIfNeeded() {
        guard fallbackListener == nil else { return }
        usingFallbackQuery = true
        let fbQuery = Firestore.firestore()
            .collection("polls")
            .whereField("partyId", isEqualTo: partyId)

        fallbackListener = fbQuery.addSnapshotListener { snap, err in
            if let err { errorMessage = err.localizedDescription; return }
            var mapped = (snap?.documents ?? []).compactMap { self.mapPoll(doc: $0) }
            mapped.sort { $0.createdAt > $1.createdAt }
            DispatchQueue.main.async {
                // Only apply fallback results if primary is still empty.
                if self.usingFallbackQuery { self.polls = mapped }
            }
        }
    }

    private func stopListening() {
        primaryListener?.remove(); primaryListener = nil
        fallbackListener?.remove(); fallbackListener = nil
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

    private func checkManagePermission() {
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else { return }
        Firestore.firestore()
            .collection("parties").document(partyId)
            .collection("members").document(uid)
            .addSnapshotListener { snap, _ in
                let role = (snap?.data()?["role"] as? String) ?? "guest"
                canManage = (role == "owner" || role == "comanager")
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
