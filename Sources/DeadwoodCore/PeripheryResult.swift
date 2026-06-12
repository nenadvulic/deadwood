import Foundation

public enum DeadwoodError: Error, Equatable, CustomStringConvertible {
    case invalidLocation(String)
    case peripheryNotFound
    case peripheryFailed(stderr: String)
    case gitFailed(stderr: String)

    public var description: String {
        switch self {
        case .invalidLocation(let s): return "could not parse location '\(s)'"
        case .peripheryNotFound: return "`periphery` was not found on PATH. Install it: https://github.com/peripheryapp/periphery"
        case .peripheryFailed(let e): return "periphery scan failed:\n\(e)"
        case .gitFailed(let e): return "git failed:\n\(e)"
        }
    }
}

/// One unused-declaration finding from `periphery scan --format json`.
public struct PeripheryResult: Decodable, Equatable {
    public struct Location: Equatable {
        public let file: String
        public let line: Int
        public let column: Int
        public init(file: String, line: Int, column: Int) {
            self.file = file; self.line = line; self.column = column
        }

        /// Parse Periphery's `"file:line:column"`. The file path may itself
        /// contain colons, so the line/column are taken from the right.
        public init(parsing string: String) throws {
            let parts = string.split(separator: ":", omittingEmptySubsequences: false)
            guard parts.count >= 3,
                  let column = Int(parts[parts.count - 1]),
                  let line = Int(parts[parts.count - 2])
            else { throw DeadwoodError.invalidLocation(string) }
            let file = parts[0..<(parts.count - 2)].joined(separator: ":")
            self.init(file: file, line: line, column: column)
        }
    }

    public let kind: String
    public let name: String
    public let accessibility: String
    public let hints: [String]
    public let usrs: [String]
    public let location: Location

    enum CodingKeys: String, CodingKey {
        case kind, name, accessibility, hints, location
        case usrs = "ids"
    }

    public init(kind: String, name: String, accessibility: String = "",
                hints: [String] = [], usrs: [String] = [], location: Location) {
        self.kind = kind; self.name = name; self.accessibility = accessibility
        self.hints = hints; self.usrs = usrs; self.location = location
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = try c.decodeIfPresent(String.self, forKey: .kind) ?? ""
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        accessibility = try c.decodeIfPresent(String.self, forKey: .accessibility) ?? ""
        hints = try c.decodeIfPresent([String].self, forKey: .hints) ?? []
        usrs = try c.decodeIfPresent([String].self, forKey: .usrs) ?? []
        location = try Location(parsing: try c.decode(String.self, forKey: .location))
    }
}
