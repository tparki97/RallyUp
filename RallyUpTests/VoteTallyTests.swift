import XCTest
@testable import RallyUp

final class VoteTallyTests: XCTestCase {

    func testCountSelections() {
        let opts = ["a", "b", "c"]
        let ballots = [
            ["a"], ["a", "b"], ["b"], ["c"], ["a"]
        ]
        let counts = VoteTally.countSelections(optionIds: opts, votes: ballots)
        XCTAssertEqual(counts["a"], 3)
        XCTAssertEqual(counts["b"], 2)
        XCTAssertEqual(counts["c"], 1)
    }

    func testBordaScores() {
        // 3 options: top gets 2, then 1, then 0
        let opts = ["x", "y", "z"]
        let rankings = [
            ["x", "y", "z"], // x+2, y+1
            ["y", "x", "z"], // y+2, x+1
            ["y", "z", "x"]  // y+2, z+1
        ]
        let scores = VoteTally.bordaScores(optionIds: opts, rankings: rankings)
        XCTAssertEqual(scores["y"], 5) // 1+2+2
        XCTAssertEqual(scores["x"], 3) // 2+1+0
        XCTAssertEqual(scores["z"], 1) // 0+0+1
    }

    func testPercentages() {
        let pcts = VoteTally.percentages(from: ["a": 2, "b": 1])
        let a = pcts["a"] ?? -1
        let b = pcts["b"] ?? -1
        XCTAssertEqual(a, 2.0 / 3.0, accuracy: 0.0001)
        XCTAssertEqual(b, 1.0 / 3.0, accuracy: 0.0001)
    }
}
