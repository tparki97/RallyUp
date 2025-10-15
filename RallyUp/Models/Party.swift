import Foundation

enum MemberRole: String, Codable {
    case owner, comanager, guest
}

struct Party: Identifiable {
    let id: String
    let ownerId: String
    var title: String
    var description: String?
    var startAt: Date?
    var themeColorHex: String?
    var joinCode: String
}

/// Compact row data mirrored under users/{uid}/myParties/{partyId}
struct PartySummary: Identifiable {
    let id: String
    let title: String
    let role: MemberRole
    let startAt: Date?
}
