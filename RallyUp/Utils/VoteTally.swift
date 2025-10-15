import Foundation

/// Utilities for tallying poll results.
/// - Single/Multiple: simple occurrence counts per option.
/// - Ranked: Borda count (n-1 points for top, …, 0 for last).
enum VoteTally {
    static func countSelections(optionIds: [String], votes: [[String]]) -> [String: Int] {
        var counts: [String: Int] = [:]
        for id in optionIds { counts[id] = 0 }
        for ballot in votes {
            for id in ballot where optionIds.contains(id) {
                counts[id, default: 0] += 1
            }
        }
        return counts
    }

    static func bordaScores(optionIds: [String], rankings: [[String]]) -> [String: Int] {
        var scores: [String: Int] = [:]
        for id in optionIds { scores[id] = 0 }
        let n = optionIds.count
        guard n > 1 else { return scores }
        for ranking in rankings {
            for (idx, id) in ranking.enumerated() where optionIds.contains(id) {
                let pts = max(0, n - idx - 1)
                scores[id, default: 0] += pts
            }
        }
        return scores
    }

    static func percentages(from counts: [String: Int]) -> [String: Double] {
        let total = max(1, counts.values.reduce(0, +))
        var out: [String: Double] = [:]
        for (id, c) in counts {
            out[id] = Double(c) / Double(total)
        }
        return out
    }
}
