import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class RSVPViewModel: ObservableObject {
    let partyId: String
    @Published var status: RSVPStatus = .maybe
    @Published var partySize: Int = 1
    @Published var notes: String = ""
    @Published var summary = RSVPSummary()

    private var myListener: ListenerRegistration?
    private var sumListener: ListenerRegistration?

    init(partyId: String) {
        self.partyId = partyId
    }

    func start() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        myListener = FirestoreService.shared.listenMyRSVP(partyId: partyId, uid: uid) { [weak self] rsvp in
            Task { @MainActor in
                if let r = rsvp {
                    self?.status = r.status
                    self?.partySize = max(1, r.status == .no ? 0 : r.partySize)
                    self?.notes = r.notes ?? ""
                }
            }
        }
        sumListener = FirestoreService.shared.listenRSVPSummary(partyId: partyId) { [weak self] s in
            Task { @MainActor in self?.summary = s }
        }
    }

    func stop() {
        myListener?.remove(); myListener = nil
        sumListener?.remove(); sumListener = nil
    }

    func save() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let size = (status == .no) ? 0 : max(1, partySize)
        do {
            try await FirestoreService.shared.setRSVP(
                partyId: partyId,
                uid: uid,
                status: status,
                partySize: size,
                notes: notes.isEmpty ? nil : notes
            )
        } catch {
            print("RSVP save failed: \(error.localizedDescription)")
        }
    }
}
