import XCTest
@testable import DeadwoodCore

private struct StubRunner: PeripheryRunner {
    let json: String
    func scanJSON(passthroughArgs: [String]) throws -> String { json }
}
private struct StubDiff: GitDiffProvider {
    let diff: String
    func unifiedDiff(since: String) throws -> String { diff }
}

final class DeadwoodEngineTests: XCTestCase {
    func testReportsOnlyDeadCodeInsideTheDiff() throws {
        let json = """
        [
          {"kind":"function.free","name":"newDead","accessibility":"internal","ids":["s:1"],
           "hints":["unused"],"location":"/repo/Sources/App/F.swift:41:1"},
          {"kind":"function.free","name":"oldDead","accessibility":"internal","ids":["s:2"],
           "hints":["unused"],"location":"/repo/Sources/App/F.swift:999:1"}
        ]
        """
        let diff = """
        --- a/Sources/App/F.swift
        +++ b/Sources/App/F.swift
        @@ -40,0 +41,1 @@
        +func newDead() {}
        """
        let engine = DeadwoodEngine(runner: StubRunner(json: json), diffProvider: StubDiff(diff: diff))
        let result = try engine.run(since: "HEAD", format: .text, peripheryArgs: [])

        XCTAssertTrue(result.hasFindings)
        XCTAssertTrue(result.report.contains("newDead"))
        XCTAssertFalse(result.report.contains("oldDead"))
    }

    func testNoFindingsWhenDiffTouchesNothingDead() throws {
        let json = """
        [{"kind":"function.free","name":"oldDead","accessibility":"internal","ids":["s:2"],
          "hints":["unused"],"location":"/repo/Sources/App/F.swift:999:1"}]
        """
        let diff = """
        --- a/Sources/App/F.swift
        +++ b/Sources/App/F.swift
        @@ -40,0 +41,1 @@
        +func stillUsed() {}
        """
        let engine = DeadwoodEngine(runner: StubRunner(json: json), diffProvider: StubDiff(diff: diff))
        let result = try engine.run(since: "HEAD", format: .text, peripheryArgs: [])
        XCTAssertFalse(result.hasFindings)
        XCTAssertEqual(result.report, "No new dead code in this change.")
    }
}
