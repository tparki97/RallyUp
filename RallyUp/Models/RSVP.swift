import Foundation

enum RSVPStatus: String, Codable, CaseIterable, Identifiable {
    case yes, maybe, no
    var id: String { rawValue }
    var label: String {
        switch self {
        case .yes: return "Yes"
        case .maybe: return "Maybe"
        case .no: return "No"
        }
    }
}

struct RSVP: Identifiable, Codable {
    var id: String { userId }
    let userId: String
    var status: RSVPStatus
    var partySize: Int
    var notes: String?
    var updatedAt: Date
}

struct RSVPSummary: Equatable {
    var yesCount: Int = 0
    var maybeCount: Int = 0
    var noCount: Int = 0
    var headcountYes: Int = 0
}
