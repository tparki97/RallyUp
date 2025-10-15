import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class PollsViewModel: ObservableObject {
    let partyId: String
    @Published var polls: [Poll] = []
    @Published var errorMessage: String?

    private var listener: ListenerRegistration?

    init(partyId: String) { self.partyId = partyId }

    func start() {
        stop()
        listener = FirestoreService.shared.listenPolls(partyId: partyId) { [weak self] items in
            Task { @MainActor in self?.polls = items }
        }
    }

    func stop() {
        listener?.remove(); listener = nil
    }

    func create(question: String, type: PollType, allowGuestOptions: Bool, deadline: Date?) async -> Poll? {
        guard let uid = Auth.auth().currentUser?.uid else { return nil }
        do {
            return try await FirestoreService.shared.createPoll(
                partyId: partyId,
                createdBy: uid,
                type: type,
                question: question,
                allowGuestOptions: allowGuestOptions,
                deadlineAt: deadline
            )
        } catch {
            await MainActor.run { self.errorMessage = error.localizedDescription }
            return nil
        }
    }

    static func isClosed(_ poll: Poll) -> Bool {
        if poll.isLocked { return true }
        if let d = poll.deadlineAt { return d < Date() }
        return false
    }
}
