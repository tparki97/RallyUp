import Foundation
import FirebaseFirestore
import FirebaseAuth

/// Thin Firestore wrapper for Parties, RSVP, and Polls.
final class FirestoreService {
    static let shared = FirestoreService()
    private init() {}

    private let db = Firestore.firestore()

    // MARK: - Helpers

    private func generateJoinCode() -> String {
        let chars = Array("ABCDEFGHJKMNPQRSTUVWXYZ23456789")
        return String((0..<6).map { _ in chars.randomElement()! })
    }

    private func userPartiesRef(uid: String) -> CollectionReference {
        db.collection("users").document(uid).collection("myParties")
    }

    private func invitesRef() -> CollectionReference {
        db.collection("invites")
    }

    // MARK: - Parties

    func createParty(ownerUid: String,
                     title: String,
                     description: String?,
                     startAt: Date?) async throws -> Party {
        // Ensure unique join code by checking /invites/{code} (allowed by rules)
        var code = generateJoinCode()
        for _ in 0..<8 {
            let inviteDoc = try await invitesRef().document(code).getDocument()
            if !inviteDoc.exists { break } // code is free
            code = generateJoinCode()
        }

        let partyRef = db.collection("parties").document()
        let now = FieldValue.serverTimestamp()

        let data: [String: Any] = [
            "ownerId": ownerUid,
            "createdBy": ownerUid, // <-- add for compatibility
            "title": title,
            "description": description as Any,
            "startAt": startAt.map { Timestamp(date: $0) } as Any,
            "themeColor": "#14B8A6",
            "joinCode": code,
            "createdAt": now,
            // Root-level membership/admin maps required by rules
            "members": [ownerUid: true],
            "admins":  [ownerUid: true],
            "visibility": "private"
        ]

        try await partyRef.setData(data)

        // Compact row for "My Parties"
        try await userPartiesRef(uid: ownerUid).document(partyRef.documentID).setData([
            "title": title,
            "role": "owner",
            "startAt": startAt.map { Timestamp(date: $0) } as Any,
            "addedAt": now
        ])

        // Public invite mapping: invites/{code} -> partyId
        try await invitesRef().document(code).setData([
            "code": code,
            "partyId": partyRef.documentID,
            "createdAt": now
        ])

        return Party(
            id: partyRef.documentID,
            ownerId: ownerUid,
            title: title,
            description: description,
            startAt: startAt,
            themeColorHex: "#14B8A6",
            joinCode: code
        )
    }

    enum JoinResult { case joined(Party), alreadyMember(Party), notFound }

    func joinParty(currentUid: String, code rawCode: String) async throws -> JoinResult {
        let code = rawCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !code.isEmpty else { return .notFound }

        // 1) Lookup invite
        let inviteSnap = try await invitesRef().document(code).getDocument()
        guard let invite = inviteSnap.data(),
              let partyId = invite["partyId"] as? String else { return .notFound }

        // 2) Fetch party
        let doc = try await db.collection("parties").document(partyId).getDocument()
        guard let pData = doc.data() else { return .notFound }

        // 3) Ensure membership in root map
        let already = (pData["members"] as? [String: Bool])?[currentUid] == true
        if !already {
            try await doc.reference.setData(["members": [currentUid: true]], merge: true)
        }

        // 4) Add to user's "My Parties"
        let title = (pData["title"] as? String) ?? "Party"
        let startAt = pData["startAt"] as? Timestamp
        try await userPartiesRef(uid: currentUid).document(partyId).setData([
            "title": title,
            "role": "guest",
            "startAt": startAt as Any,
            "addedAt": FieldValue.serverTimestamp()
        ])

        let party = Party(
            id: partyId,
            ownerId: (pData["ownerId"] as? String) ?? "",
            title: title,
            description: pData["description"] as? String,
            startAt: startAt?.dateValue(),
            themeColorHex: (pData["themeColor"] as? String) ?? "#14B8A6",
            joinCode: (pData["joinCode"] as? String) ?? code
        )
        return already ? .alreadyMember(party) : .joined(party)
    }

    // --- rest of file unchanged (RSVP + Polls API) ---

    func listenMyParties(uid: String, onChange: @escaping ([PartySummary]) -> Void) -> ListenerRegistration {
        userPartiesRef(uid: uid)
            .order(by: "addedAt", descending: true)
            .addSnapshotListener { snap, _ in
                var items: [PartySummary] = []
                snap?.documents.forEach { d in
                    let ts = d.data()["startAt"] as? Timestamp
                    let roleStr = (d.data()["role"] as? String) ?? "guest"
                    let summary = PartySummary(
                        id: d.documentID,
                        title: (d.data()["title"] as? String) ?? "Party",
                        role: MemberRole(rawValue: roleStr) ?? .guest,
                        startAt: ts?.dateValue()
                    )
                    items.append(summary)
                }
                onChange(items)
            }
    }

    func fetchParty(partyId: String) async throws -> Party? {
        let doc = try await db.collection("parties").document(partyId).getDocument()
        guard let data = doc.data() else { return nil }
        return Party(
            id: doc.documentID,
            ownerId: (data["ownerId"] as? String) ?? "",
            title: (data["title"] as? String) ?? "Party",
            description: data["description"] as? String,
            startAt: (data["startAt"] as? Timestamp)?.dateValue(),
            themeColorHex: (data["themeColor"] as? String) ?? "#14B8A6",
            joinCode: (data["joinCode"] as? String) ?? ""
        )
    }

    // RSVP
    func setRSVP(partyId: String, uid: String, status: RSVPStatus, partySize: Int, notes: String?) async throws {
        let rsvpRef = db.collection("parties").document(partyId)
            .collection("rsvps").document(uid)
        try await rsvpRef.setData([
            "userId": uid,
            "status": status.rawValue,
            "partySize": max(0, partySize),
            "notes": notes as Any,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    func listenMyRSVP(partyId: String, uid: String, onChange: @escaping (RSVP?) -> Void) -> ListenerRegistration {
        db.collection("parties").document(partyId)
            .collection("rsvps").document(uid)
            .addSnapshotListener { snap, _ in
                guard let d = snap?.data(),
                      let statusStr = d["status"] as? String,
                      let status = RSVPStatus(rawValue: statusStr) else {
                    onChange(nil); return
                }
                let r = RSVP(
                    userId: uid,
                    status: status,
                    partySize: (d["partySize"] as? Int) ?? 1,
                    notes: d["notes"] as? String,
                    updatedAt: (d["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
                )
                onChange(r)
            }
    }

    func listenRSVPSummary(partyId: String, onChange: @escaping (RSVPSummary) -> Void) -> ListenerRegistration {
        db.collection("parties").document(partyId)
            .collection("rsvps")
            .addSnapshotListener { snap, _ in
                var s = RSVPSummary()
                snap?.documents.forEach { d in
                    let status = (d["status"] as? String).flatMap(RSVPStatus.init(rawValue:)) ?? .maybe
                    let size = (d["partySize"] as? Int) ?? 0
                    switch status {
                    case .yes: s.yesCount += 1; s.headcountYes += max(0, size)
                    case .maybe: s.maybeCount += 1
                    case .no: s.noCount += 1
                    }
                }
                onChange(s)
            }
    }

    // POLLS
    private func pollsRef(partyId: String) -> CollectionReference {
        db.collection("parties").document(partyId).collection("polls")
    }
    private func optionsRef(partyId: String, pollId: String) -> CollectionReference {
        pollsRef(partyId: partyId).document(pollId).collection("options")
    }
    private func votesRef(partyId: String, pollId: String) -> CollectionReference {
        pollsRef(partyId: partyId).document(pollId).collection("votes")
    }

    func createPoll(partyId: String,
                    createdBy: String,
                    type: PollType,
                    question: String,
                    allowGuestOptions: Bool,
                    deadlineAt: Date?) async throws -> Poll {
        let doc = pollsRef(partyId: partyId).document()
        try await doc.setData([
            "partyId": partyId,
            "type": type.rawValue,
            "question": question,
            "allowGuestOptions": allowGuestOptions,
            "isLocked": false,
            "deadlineAt": deadlineAt.map { Timestamp(date: $0) } as Any,
            "createdBy": createdBy,
            "createdAt": FieldValue.serverTimestamp()
        ])
        return Poll(id: doc.documentID, partyId: partyId, type: type, question: question,
                    allowGuestOptions: allowGuestOptions, isLocked: false,
                    deadlineAt: deadlineAt, createdBy: createdBy, createdAt: nil)
    }

    func addOption(partyId: String, pollId: String, text: String, createdBy: String, rank: Int) async throws {
        let ref = optionsRef(partyId: partyId, pollId: pollId).document()
        try await ref.setData([
            "text": text,
            "createdBy": createdBy,
            "rank": rank,
            "createdAt": FieldValue.serverTimestamp()
        ])
    }

    func listenPolls(partyId: String, onChange: @escaping ([Poll]) -> Void) -> ListenerRegistration {
        pollsRef(partyId: partyId)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snap, _ in
                var items: [Poll] = []
                snap?.documents.forEach { d in
                    let data = d.data()
                    let typeStr = (data["type"] as? String) ?? "single"
                    let type = PollType(rawValue: typeStr) ?? .single
                    let p = Poll(
                        id: d.documentID,
                        partyId: (data["partyId"] as? String) ?? "",
                        type: type,
                        question: (data["question"] as? String) ?? "",
                        allowGuestOptions: (data["allowGuestOptions"] as? Bool) ?? false,
                        isLocked: (data["isLocked"] as? Bool) ?? false,
                        deadlineAt: (data["deadlineAt"] as? Timestamp)?.dateValue(),
                        createdBy: (data["createdBy"] as? String) ?? "",
                        createdAt: (data["createdAt"] as? Timestamp)?.dateValue()
                    )
                    items.append(p)
                }
                onChange(items)
            }
    }

    func listenOptions(partyId: String, pollId: String, onChange: @escaping ([PollOption]) -> Void) -> ListenerRegistration {
        optionsRef(partyId: partyId, pollId: pollId)
            .order(by: "rank")
            .addSnapshotListener { snap, _ in
                var items: [PollOption] = []
                var i = 0
                snap?.documents.forEach { d in
                    let data = d.data()
                    let option = PollOption(
                        id: d.documentID,
                        text: (data["text"] as? String) ?? "",
                        createdBy: (data["createdBy"] as? String) ?? "",
                        createdAt: (data["createdAt"] as? Timestamp)?.dateValue(),
                        rank: (data["rank"] as? Int) ?? i
                    )
                    i += 1
                    items.append(option)
                }
                onChange(items)
            }
    }

    func hasUserVoted(partyId: String, pollId: String, uid: String) async throws -> Bool {
        try await votesRef(partyId: partyId, pollId: pollId).document(uid).getDocument().exists
    }

    func submitVoteSingle(partyId: String, pollId: String, uid: String, optionId: String) async throws {
        try await votesRef(partyId: partyId, pollId: pollId).document(uid).setData([
            "type": "single",
            "selectedOptionIds": [optionId],
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    func submitVoteMultiple(partyId: String, pollId: String, uid: String, optionIds: [String]) async throws {
        try await votesRef(partyId: partyId, pollId: pollId).document(uid).setData([
            "type": "multiple",
            "selectedOptionIds": optionIds,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    /// Simple per-option tally.
    func fetchTallies(partyId: String, pollId: String) async throws -> [String: Int] {
        let snap = try await votesRef(partyId: partyId, pollId: pollId).getDocuments()
        var counts: [String: Int] = [:]
        for d in snap.documents {
            let data = d.data()
            if let ids = data["selectedOptionIds"] as? [String] {
                ids.forEach { counts[$0, default: 0] += 1 }
            }
        }
        return counts
    }
}
