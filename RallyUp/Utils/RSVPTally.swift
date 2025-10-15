import Foundation

enum RSVPTally {
    /// Reduce a list of (status, partySize) into a summary.
    static func compute(from entries: [(RSVPStatus, Int)]) -> RSVPSummary {
        var s = RSVPSummary()
        for (status, size) in entries {
            switch status {
            case .yes:
                s.yesCount += 1
                s.headcountYes += max(0, size)
            case .maybe:
                s.maybeCount += 1
            case .no:
                s.noCount += 1
            }
        }
        return s
    }
}
