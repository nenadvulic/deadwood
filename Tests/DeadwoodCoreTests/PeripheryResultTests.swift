import XCTest
@testable import DeadwoodCore

final class PeripheryResultTests: XCTestCase {
    // A real `periphery scan --format json` element.
    func testDecodesPeripheryJSON() throws {
        let json = """
        [
          {
            "kind": "function.free",
            "modules": ["App"],
            "name": "unusedHelper",
            "modifiers": [],
            "attributes": [],
            "accessibility": "internal",
            "ids": ["s:3App12unusedHelperyyF"],
            "hints": ["unused"],
            "location": "/repo/Sources/App/Helpers.swift:42:6"
          }
        ]
        """
        let results = try JSONDecoder().decode([PeripheryResult].self, from: Data(json.utf8))
        XCTAssertEqual(results.count, 1)
        let r = results[0]
        XCTAssertEqual(r.name, "unusedHelper")
        XCTAssertEqual(r.kind, "function.free")
        XCTAssertEqual(r.hints, ["unused"])
        XCTAssertEqual(r.usrs, ["s:3App12unusedHelperyyF"])
        XCTAssertEqual(r.location, .init(file: "/repo/Sources/App/Helpers.swift", line: 42, column: 6))
    }

    func testLocationParsingKeepsColonsInPath() throws {
        let loc = try PeripheryResult.Location(parsing: "a/b/File.swift:10:3")
        XCTAssertEqual(loc, .init(file: "a/b/File.swift", line: 10, column: 3))
    }

    func testLocationParsingRejectsMalformed() {
        XCTAssertThrowsError(try PeripheryResult.Location(parsing: "no-line-or-col"))
    }
}
