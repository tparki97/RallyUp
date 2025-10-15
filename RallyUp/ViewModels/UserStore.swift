import Foundation
import Combine

@MainActor
final class UserStore: ObservableObject {
    @Published var displayName: String = ""
    @Published var email: String = ""
    @Published var preferences: [String: Bool] = [:]

    init() {}

    func updateDisplayName(_ name: String) {
        displayName = name
    }

    func setPreference(_ key: String, value: Bool) {
        preferences[key] = value
    }
}
