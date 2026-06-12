import XCTest
@testable import DeadwoodCore

final class ReporterTests: XCTestCase {
    private let results = [
        PeripheryResult(kind: "function.free", name: "unusedHelper", accessibility: "internal",
                        hints: ["unused"], usrs: ["s:1"],
                        location: .init(file: "Sources/App/Helpers.swift", line: 42, column: 6)),
    ]

    func testTextReport() {
        let out = Reporter.render(results, format: .text)
        XCTAssertEqual(out, """
        1 new unused declaration(s) in this change:
          Sources/App/Helpers.swift:42: function.free unusedHelper — unused
        """)
    }

    func testTextReportEmpty() {
        XCTAssertEqual(Reporter.render([], format: .text), "No new dead code in this change.")
    }

    func testJSONReport() throws {
        let out = Reporter.render(results, format: .json)
        let decoded = try JSONSerialization.jsonObject(with: Data(out.utf8)) as? [[String: Any]]
        XCTAssertEqual(decoded?.count, 1)
        XCTAssertEqual(decoded?.first?["name"] as? String, "unusedHelper")
        XCTAssertEqual(decoded?.first?["file"] as? String, "Sources/App/Helpers.swift")
        XCTAssertEqual(decoded?.first?["line"] as? Int, 42)
    }
}
