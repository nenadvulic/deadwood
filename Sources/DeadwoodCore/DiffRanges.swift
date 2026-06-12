import Foundation

/// Changed (added/modified) line numbers on the new side of a unified diff,
/// keyed by the new-side file path (repo-relative, the `b/` path).
public struct DiffRanges: Equatable {
    public private(set) var byFile: [String: Set<Int>]

    public init(byFile: [String: Set<Int>] = [:]) { self.byFile = byFile }

    /// Parse the output of `git diff --unified=0 ...`.
    public static func parse(unifiedDiff: String) -> DiffRanges {
        var byFile: [String: Set<Int>] = [:]
        var currentFile: String?

        for raw in unifiedDiff.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(raw)
            if line.hasPrefix("+++ ") {
                var path = String(line.dropFirst(4))
                if path.hasPrefix("b/") { path = String(path.dropFirst(2)) }
                currentFile = (path == "/dev/null") ? nil : path
            } else if line.hasPrefix("@@"), let file = currentFile,
                      let newLines = newLineNumbers(inHunkHeader: line) {
                byFile[file, default: []].formUnion(newLines)
            }
        }
        return DiffRanges(byFile: byFile)
    }

    /// From `@@ -a,b +c,d @@`, return the new-side line numbers `c ..< c+d`.
    /// Returns nil when the hunk adds no lines (`d == 0`, a pure deletion).
    static func newLineNumbers(inHunkHeader header: String) -> [Int]? {
        guard let plusIndex = header.firstIndex(of: "+") else { return nil }
        let token = header[header.index(after: plusIndex)...].prefix { $0.isNumber || $0 == "," }
        let nums = token.split(separator: ",").compactMap { Int($0) }
        guard let start = nums.first else { return nil }
        let count = nums.count > 1 ? nums[1] : 1
        guard count > 0 else { return nil }
        return Array(start ..< (start + count))
    }
}
