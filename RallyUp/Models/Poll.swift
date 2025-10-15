import Foundation

enum PollType: String, Codable, CaseIterable, Identifiable {
    case single
    case multiple
    case ranked // UI later
    var id: String { rawValue }
    var label: String {
        switch self {
        case .single: return "Single choice"
        case .multiple: return "Multiple choice"
        case .ranked: return "Ranked (later)"
        }
    }
}

struct Poll: Identifiable {
    let id: String
    let partyId: String
    let type: PollType
    let question: String
    let allowGuestOptions: Bool
    let isLocked: Bool
    let deadlineAt: Date?
    let createdBy: String
    let createdAt: Date?
}

struct PollOption: Identifiable, Hashable {
    let id: String
    let text: String
    let createdBy: String
    let createdAt: Date?
    let rank: Int
}
