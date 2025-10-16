import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

/// Local enum so we don't collide with your project's PollType
enum PollKind: String {
    case single, multiple, ranked

    init(_ raw: String) {
        switch raw.lowercased() {
        case "ranked": self = .ranked
        case "multiple", "multiplechoice", "multi": self = .multiple
        default: self = .single
        }
    }
}

/// Local option model so we don't collide with your PollOption
struct VoteOption: Identifiable, Equatable {
    let id: String
    let text: String
    var rank: Int
}

@MainActor
final class VoteViewModel: ObservableObject {

    // MARK: - Public, observed poll fields
    @Published var question: String = ""
    @Published var pollKind: PollKind = .single
    @Published var allowGuestOptions: Bool = false
    @Published var isLocked: Bool = false
    @Published var deadlineAt: Date? = nil
    @Published var createdBy: String = ""

    // MARK: - Options & selections
    @Published var options: [VoteOption] = []
    @Published var selectedOptionIds: Set<String> = []     // single/multiple
    @Published var rankedOrder: [VoteOption] = []          // ranked order

    // MARK: - Vote/result state
    @Published var hasVoted: Bool = false
    @Published var totalBallots: Int = 0
    @Published private(set) var counts: [String: Int] = [:]          // for single/multiple
    @Published private(set) var bordaScores: [String: Double] = [:]  // for ranked
    @Published private(set) var percentages: [String: Double] = [:]  // 0...1 for UI bars

    // MARK: - Computed flags the View needs
    var isClosed: Bool {
        if isLocked { return true }
        if let d = deadlineAt { return d < Date() }
        return false
    }

    var canSubmit: Bool {
        guard !isClosed else { return false }
        switch pollKind {
        case .single:   return selectedOptionIds.count == 1
        case .multiple: return selectedOptionIds.count >= 1
        case .ranked:   return rankedOrder.count >= 2
        }
    }

    var shouldShowResults: Bool { hasVoted || isClosed }

    var isCreator: Bool {
        guard let uid = Auth.auth().currentUser?.uid else { return false }
        return createdBy == uid
    }

    // MARK: - Internals
    private let partyId: String
    private let pollId: String
    private let db = Firestore.firestore()

    private var pollListener: ListenerRegistration?
    private var optionsListener: ListenerRegistration?
    private var votesListener: ListenerRegistration?

    init(partyId: String, pollId: String) {
        self.partyId = partyId
        self.pollId = pollId
        startListeners()
    }

    deinit {
        pollListener?.remove()
        optionsListener?.remove()
        votesListener?.remove()
    }

    // MARK: - Listeners

    private func startListeners() {
        let pollRef = db.collection("parties").document(partyId).collection("polls").document(pollId)

        // Poll doc (fields and meta)
        pollListener = pollRef.addSnapshotListener { [weak self] snap, _ in
            guard let self, let data = snap?.data(), snap?.exists == true else { return }
            Task { @MainActor in
                self.question = (data["question"] as? String) ?? ""
                self.pollKind = PollKind((data["type"] as? String) ?? "single")
                self.allowGuestOptions = (data["allowGuestOptions"] as? Bool) ?? false
                self.isLocked = (data["isLocked"] as? Bool) ?? false
                self.deadlineAt = (data["deadlineAt"] as? Timestamp)?.dateValue()
                self.createdBy = (data["createdBy"] as? String) ?? ""
                self.updateVotesListenerIfNeeded(pollRef: pollRef)
            }
        }

        // Options subcollection
        optionsListener = pollRef.collection("options")
            .order(by: "rank", descending: false)
            .addSnapshotListener { [weak self] snap, _ in
                guard let self else { return }
                let parsed: [VoteOption] = snap?.documents.map { doc in
                    let data = doc.data()
                    return VoteOption(
                        id: doc.documentID,
                        text: data["text"] as? String ?? "",
                        rank: data["rank"] as? Int ?? 0
                    )
                } ?? []

                Task { @MainActor in
                    self.options = parsed
                    if self.pollKind == .ranked {
                        // Merge any existing user order with new options
                        let existingIds = Set(self.rankedOrder.map(\.id))
                        var merged = self.rankedOrder.filter { opt in parsed.contains(where: { $0.id == opt.id }) }
                        merged.append(contentsOf: parsed.filter { !existingIds.contains($0.id) })
                        self.rankedOrder = merged.isEmpty ? parsed : merged
                    }
                }
            }

        // Determine if I have voted without querying the whole collection (allowed by rules)
        fetchHasVoted(pollRef: pollRef)
    }

    /// Read only my vote doc once to set `hasVoted`, then decide whether to attach the full votes listener.
    private func fetchHasVoted(pollRef: DocumentReference) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        pollRef.collection("votes").document(uid).getDocument { [weak self] snap, _ in
            guard let self else { return }
            Task { @MainActor in
                self.hasVoted = (snap?.exists == true)
                self.updateVotesListenerIfNeeded(pollRef: pollRef)
            }
        }
    }

    /// Start/stop the collection listener depending on whether results should be visible.
    private func updateVotesListenerIfNeeded(pollRef: DocumentReference) {
        let canReadAllVotes = (hasVoted || isClosed)
        if canReadAllVotes {
            // If we don't already have a listener, attach it now.
            if votesListener == nil {
                votesListener = pollRef.collection("votes").addSnapshotListener { [weak self] snap, _ in
                    guard let self else { return }
                    let docs = snap?.documents ?? []
                    Task { @MainActor in
                        self.recomputeTallies(from: docs)
                    }
                }
            }
        } else {
            // Not allowed to read everyone’s votes — ensure no listener is attached and clear tallies.
            votesListener?.remove()
            votesListener = nil
            counts = [:]
            percentages = [:]
            bordaScores = [:]
            totalBallots = 0
        }
    }

    // MARK: - Tally logic

    private func recomputeTallies(from voteDocs: [QueryDocumentSnapshot]) {
        totalBallots = voteDocs.count

        switch pollKind {
        case .single, .multiple:
            var c: [String: Int] = [:]
            for d in voteDocs {
                if let ids = d.data()["selectedOptionIds"] as? [String] {
                    for id in ids { c[id, default: 0] += 1 }
                }
            }
            counts = c
            let voters = max(1, totalBallots)
            percentages = c.mapValues { Double($0) / Double(voters) }
            bordaScores = [:]

        case .ranked:
            let optionIds = options.map(\.id)
            var scores: [String: Double] = [:]
            let n = max(1, optionIds.count)

            for d in voteDocs {
                if let arr = d.data()["rankings"] as? [String] {
                    for (idx, id) in arr.enumerated() {
                        // Borda points: n-1 for rank 1, then decreasing
                        let pts = Double(max(0, n - idx - 1))
                        scores[id, default: 0] += pts
                    }
                }
            }
            bordaScores = scores

            // Normalize to 0...1 across the total sum of points cast
            let perBallotTotal = Double(n * (n - 1)) / 2.0
            let grandTotal = perBallotTotal * Double(max(0, totalBallots))
            if grandTotal > 0 {
                percentages = scores.mapValues { $0 / grandTotal }
            } else {
                percentages = [:]
            }
            counts = [:]
        }
    }

    // MARK: - UI helpers

    func percent(for optionId: String) -> Double {
        let v = percentages[optionId] ?? 0
        return v.isFinite ? v : 0
    }

    func count(for optionId: String) -> Int {
        counts[optionId] ?? 0
    }

    func score(for optionId: String) -> Double {
        bordaScores[optionId] ?? 0
    }

    // MARK: - Selection & actions

    func toggleSelect(_ optionId: String) {
        switch pollKind {
        case .single:
            selectedOptionIds = [optionId]
        case .multiple:
            if selectedOptionIds.contains(optionId) { selectedOptionIds.remove(optionId) }
            else { selectedOptionIds.insert(optionId) }
        case .ranked:
            break // drag handles update rankedOrder
        }
    }

    /// Foundation-only reordering (no SwiftUI dependency).
    func moveRanked(from source: IndexSet, to destination: Int) {
        var arr = rankedOrder
        let moving = source.sorted().map { arr[$0] }
        for i in source.sorted(by: >) { arr.remove(at: i) }
        let adjustedDest = destination - source.filter { $0 < destination }.count
        let clampedDest = max(0, min(adjustedDest, arr.count))
        arr.insert(contentsOf: moving, at: clampedDest)
        rankedOrder = arr
    }

    func addGuestOption(text: String) async throws {
        guard allowGuestOptions, !isClosed else { return }
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }

        let pollRef = db.collection("parties").document(partyId).collection("polls").document(pollId)
        let optRef = pollRef.collection("options").document()
        try await optRef.setData([
            "text": t,
            "createdBy": uid,
            "createdAt": Timestamp(date: Date()),
            "rank": (options.last?.rank ?? -1) + 1
        ])
    }

    func submitVote() async throws {
        guard !isClosed, let uid = Auth.auth().currentUser?.uid else { return }
        let pollRef = db.collection("parties").document(partyId).collection("polls").document(pollId)
        let voteRef = pollRef.collection("votes").document(uid)

        switch pollKind {
        case .single, .multiple:
            try await voteRef.setData([
                "selectedOptionIds": Array(selectedOptionIds),
                "updatedAt": Timestamp(date: Date())
            ], merge: true)

        case .ranked:
            let order = rankedOrder.map { $0.id }
            try await voteRef.setData([
                "rankings": order,
                "updatedAt": Timestamp(date: Date())
            ], merge: true)
        }

        // Mark as voted and attach results listener if applicable
        hasVoted = true
        updateVotesListenerIfNeeded(pollRef: pollRef)
    }

    func toggleLock() async {
        guard let uid = Auth.auth().currentUser?.uid, uid == createdBy else { return }
        let ref = db.collection("parties").document(partyId).collection("polls").document(pollId)
        do {
            try await ref.updateData(["isLocked": !isLocked])
        } catch {
            print("Lock toggle failed:", error.localizedDescription)
        }
    }
}
