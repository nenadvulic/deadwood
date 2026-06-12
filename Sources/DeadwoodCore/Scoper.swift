/// Keeps only the Periphery results located in the diff's changed lines.
public enum Scoper {
    public static func scope(_ results: [PeripheryResult], to diff: DiffRanges) -> [PeripheryResult] {
        results.filter { result in
            for (file, lines) in diff.byFile
            where lines.contains(result.location.line) && matches(resultFile: result.location.file, diffFile: file) {
                return true
            }
            return false
        }
    }

    /// Periphery emits absolute (or cwd-relative) paths; git diff emits
    /// repo-relative paths. Match when the result path is, or ends with, the
    /// diff path.
    static func matches(resultFile: String, diffFile: String) -> Bool {
        resultFile == diffFile || resultFile.hasSuffix("/" + diffFile)
    }
}
