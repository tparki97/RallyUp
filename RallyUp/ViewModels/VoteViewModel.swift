import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

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

struct VoteOption: Identifiable, Equatable {
    let id: String
    let text: String
    var rank: Int
}

@MainActor
final class VoteViewModel: ObservableObject {
    // Poll
    @Published var question: String = ""
    @Published var pollKind: PollKind = .single
    @Published var allowGuestOptions: Bool = false
    @Published var isLocked: Bool = false
    @Published var deadlineAt: Date? = nil

    // Options
    @Published var options: [VoteOption] = []

    // Selection
    @Published var selectedOptionIds: Set<String> = [] // single/multiple
    @Published var rankedOrder: [VoteOption] = []      // ranked

    // Results
    @Published var hasVoted: Bool = false
    @Published var resultsCounts: [String: Int] = [:]
    @Published var resultsPercentages: [String: Double] = [:]

    var canSubmit: Bool {
        switch pollKind {
        case .single: return selectedOptionIds.count == 1
        case .multiple: return !selectedOptionIds.isEmpty
        case .ranked: return rankedOrder.count >= 3
        }
    }

    var shouldShowResults: Bool {
        if hasVoted { return true }
        if isLocked { return true }
        if let d = deadlineAt, d < Date() { return true }
        return false
    }

    private let partyId: String
    private let pollId: String
    private let db = Firestore.firestore()

    private var pollListener: ListenerRegistration?
    private var optionsListener: ListenerRegistration?

    init(partyId: String, pollId: String) {
        self.partyId = partyId
        self.pollId = pollId
        startListeners()
    }

    deinit {
        pollListener?.remove()
        optionsListener?.remove()
    }

    private func pollRef() -> DocumentReference {
        db.collection("parties").document(partyId)
            .collection("polls").document(pollId)
    }

    private func startListeners() {
        let ref = pollRef()

        pollListener = ref.addSnapshotListener { [weak self] snap, _ in
            guard let self, let data = snap?.data(), snap?.exists == true else { return }
            self.question = (data["question"] as? String) ?? ""
            self.pollKind = PollKind((data["type"] as? String) ?? "single")
            self.allowGuestOptions = (data["allowGuestOptions"] as? Bool) ?? false
            self.isLocked = (data["isLocked"] as? Bool) ?? false
            self.deadlineAt = (data["deadlineAt"] as? Timestamp)?.dateValue()
        }

        optionsListener = ref.collection("options")
            .order(by: "rank")
            .addSnapshotListener { [weak self] snap, _ in
                guard let self else { return }
                let parsed: [VoteOption] = snap?.documents.enumerated().map { (idx, doc) in
                    let data = doc.data()
                    return VoteOption(
                        id: doc.documentID,
                        text: data["text"] as? String ?? "",
                        rank: data["rank"] as? Int ?? idx
                    )
                } ?? []

                self.options = parsed

                if self.pollKind == .ranked {
                    let existingIds = Set(self.rankedOrder.map(\.id))
                    var merged = self.rankedOrder.filter { opt in parsed.contains(where: { $0.id == opt.id }) }
                    merged.append(contentsOf: parsed.filter { !existingIds.contains($0.id) })
                    self.rankedOrder = merged.isEmpty ? parsed : merged
                }
            }
    }

    func toggleSelect(_ optionId: String) {
        switch pollKind {
        case .single:
            selectedOptionIds = [optionId]
        case .multiple:
            if selectedOptionIds.contains(optionId) { selectedOptionIds.remove(optionId) }
            else { selectedOptionIds.insert(optionId) }
        case .ranked:
            break
        }
    }

    func addGuestOption(text: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        let ref = pollRef().collection("options").document()
        try await ref.setData([
            "text": t,
            "createdBy": uid,
            "createdAt": Timestamp(date: Date()),
            "rank": (options.last?.rank ?? -1) + 1
        ])
    }

    func submitVote() async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let voteRef = pollRef().collection("votes").document(uid)
        switch pollKind {
        case .single, .multiple:
            try await voteRef.setData([
                "type": pollKind == .single ? "single" : "multiple",
                "selectedOptionIds": Array(selectedOptionIds),
                "updatedAt": Timestamp(date: Date())
            ], merge: true)

        case .ranked:
            let order = rankedOrder.map { $0.id }
            try await voteRef.setData([
                "type": "ranked",
                "rankings": order,
                "updatedAt": Timestamp(date: Date())
            ], merge: true)
        }
    }

    func refreshHasVoted() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            let doc = try await pollRef().collection("votes").document(uid).getDocument()
            hasVoted = doc.exists
        } catch {
            hasVoted = false
        }
    }

    func refreshTallies() async {
        let opts = options.map(\.id)
        guard !opts.isEmpty else {
            await MainActor.run {
                resultsCounts = [:]; resultsPercentages = [:]
            }
            return
        }
        do {
            let snap = try await pollRef().collection("votes").getDocuments()
            var counts: [String: Int] = [:]

            switch pollKind {
            case .single, .multiple:
                var selections: [[String]] = []
                for d in snap.documents {
                    if let ids = d.data()["selectedOptionIds"] as? [String] {
                        selections.append(ids)
                    }
                }
                counts = VoteTally.countSelections(optionIds: opts, votes: selections)

            case .ranked:
                var rankings: [[String]] = []
                for d in snap.documents {
                    if let r = d.data()["rankings"] as? [String] {
                        rankings.append(r)
                    }
                }
                counts = VoteTally.bordaScores(optionIds: opts, rankings: rankings)
            }

            let pcts = VoteTally.percentages(from: counts)
            await MainActor.run {
                self.resultsCounts = counts
                self.resultsPercentages = pcts
            }
        } catch {
            await MainActor.run {
                self.resultsCounts = [:]
                self.resultsPercentages = [:]
            }
        }
    }
}
