import XCTest
@testable import DeadwoodCore

final class ScoperTests: XCTestCase {
    private func result(_ file: String, _ line: Int) -> PeripheryResult {
        PeripheryResult(kind: "function.free", name: "f", hints: ["unused"],
                        location: .init(file: file, line: line, column: 1))
    }

    func testKeepsOnlyResultsInChangedLines() {
        let diff = DiffRanges(byFile: ["Sources/App/Helpers.swift": [41, 42, 43]])
        let results = [
            result("/repo/Sources/App/Helpers.swift", 42),   // in range -> kept
            result("/repo/Sources/App/Helpers.swift", 99),   // out of range -> dropped
            result("/repo/Sources/App/Other.swift", 42),     // other file -> dropped
        ]
        let scoped = Scoper.scope(results, to: diff)
        XCTAssertEqual(scoped.count, 1)
        XCTAssertEqual(scoped.first?.location.line, 42)
    }

    func testMatchesAbsoluteResultPathAgainstRepoRelativeDiffPath() {
        let diff = DiffRanges(byFile: ["Sources/App/Helpers.swift": [10]])
        let scoped = Scoper.scope([result("/abs/repo/Sources/App/Helpers.swift", 10)], to: diff)
        XCTAssertEqual(scoped.count, 1)
    }
}
