import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class PartiesViewModel: ObservableObject {
    @Published var parties: [PartySummary] = []
    @Published var errorMessage: String?
    private var listener: ListenerRegistration?

    func start(uid: String) {
        stop()
        listener = FirestoreService.shared.listenMyParties(uid: uid) { [weak self] items in
            Task { @MainActor in self?.parties = items }
        }
    }

    func stop() {
        listener?.remove()
        listener = nil
    }

    func createParty(title: String, date: Date?) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            _ = try await FirestoreService.shared.createParty(
                ownerUid: uid,
                title: title,
                description: nil,
                startAt: date
            )
        } catch {
            await MainActor.run { self.errorMessage = error.localizedDescription }
        }
    }

    func join(code: String) async -> FirestoreService.JoinResult? {
        guard let uid = Auth.auth().currentUser?.uid else { return nil }
        do {
            return try await FirestoreService.shared.joinParty(currentUid: uid, code: code)
        } catch {
            await MainActor.run { self.errorMessage = error.localizedDescription }
            return nil
        }
    }
}
