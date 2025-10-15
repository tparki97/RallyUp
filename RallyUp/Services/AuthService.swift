import Foundation
import Combine
import FirebaseAuth

/// Observes Firebase auth state (Anonymous Auth for now).
final class AuthService: ObservableObject {
    @Published var uid: String?

    private var handle: AuthStateDidChangeListenerHandle?

    init() {
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.uid = user?.uid
        }
    }

    deinit {
        if let handle { Auth.auth().removeStateDidChangeListener(handle) }
    }

    func signOut() {
        try? Auth.auth().signOut()
    }
}
