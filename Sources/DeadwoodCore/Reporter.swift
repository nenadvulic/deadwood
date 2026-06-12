import Foundation

public enum ReportFormat: String {
    case text, json
}

public enum Reporter {
    public static func render(_ results: [PeripheryResult], format: ReportFormat) -> String {
        switch format {
        case .text: return text(results)
        case .json: return json(results)
        }
    }

    private static func text(_ results: [PeripheryResult]) -> String {
        guard !results.isEmpty else { return "No new dead code in this change." }
        var lines = ["\(results.count) new unused declaration(s) in this change:"]
        for r in results {
            let hint = r.hints.first.map { " — \($0)" } ?? ""
            lines.append("  \(r.location.file):\(r.location.line): \(r.kind) \(r.name)\(hint)")
        }
        return lines.joined(separator: "\n")
    }

    private struct Item: Encodable {
        let file: String, line: Int, column: Int
        let kind: String, name: String, accessibility: String
        let hints: [String], usrs: [String]
    }

    private static func json(_ results: [PeripheryResult]) -> String {
        let items = results.map {
            Item(file: $0.location.file, line: $0.location.line, column: $0.location.column,
                 kind: $0.kind, name: $0.name, accessibility: $0.accessibility,
                 hints: $0.hints, usrs: $0.usrs)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(items), let s = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return s
    }
}
