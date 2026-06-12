import XCTest
@testable import DeadwoodCore

final class DiffRangesTests: XCTestCase {
    func testParsesAddedLinesPerFile() {
        let diff = """
        diff --git a/Sources/App/Helpers.swift b/Sources/App/Helpers.swift
        index 1111111..2222222 100644
        --- a/Sources/App/Helpers.swift
        +++ b/Sources/App/Helpers.swift
        @@ -40,0 +41,3 @@ import Foundation
        +func unusedHelper() {}
        +
        +func used() {}
        @@ -100,1 +103,1 @@
        +let x = 1
        """
        let ranges = DiffRanges.parse(unifiedDiff: diff)
        XCTAssertEqual(ranges.byFile["Sources/App/Helpers.swift"], [41, 42, 43, 103])
    }

    func testPureDeletionAddsNoLines() {
        let diff = """
        --- a/F.swift
        +++ b/F.swift
        @@ -10,2 +9,0 @@
        -let dead = 1
        -let dead2 = 2
        """
        let ranges = DiffRanges.parse(unifiedDiff: diff)
        XCTAssertNil(ranges.byFile["F.swift"])
    }

    func testNewFileUsesDevNullOldSide() {
        let diff = """
        --- /dev/null
        +++ b/New.swift
        @@ -0,0 +1,2 @@
        +struct New {}
        +
        """
        let ranges = DiffRanges.parse(unifiedDiff: diff)
        XCTAssertEqual(ranges.byFile["New.swift"], [1, 2])
    }
}
