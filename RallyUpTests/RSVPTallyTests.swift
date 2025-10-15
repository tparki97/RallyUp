import XCTest
@testable import RallyUp

final class RSVPTallyTests: XCTestCase {
    func testTally() {
        // 3 yes (sizes 2,1,4), 2 maybe, 1 no
        let entries: [(RSVPStatus, Int)] = [
            (.yes, 2), (.yes, 1), (.yes, 4),
            (.maybe, 1), (.maybe, 3),
            (.no, 0)
        ]
        let s = RSVPTally.compute(from: entries)
        XCTAssertEqual(s.yesCount, 3)
        XCTAssertEqual(s.maybeCount, 2)
        XCTAssertEqual(s.noCount, 1)
        XCTAssertEqual(s.headcountYes, 7)
    }
}
