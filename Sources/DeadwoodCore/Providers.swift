import Foundation

public protocol PeripheryRunner {
    /// Runs `periphery scan --format json` and returns raw JSON.
    func scanJSON(passthroughArgs: [String]) throws -> String
}

public protocol GitDiffProvider {
    /// Runs `git diff --unified=0 <since>` and returns the unified diff.
    func unifiedDiff(since: String) throws -> String
}

/// Runs a subprocess, returning (stdout, stderr, exit code).
enum Subprocess {
    static func run(_ executable: String, _ args: [String]) throws -> (stdout: String, stderr: String, code: Int32) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [executable] + args
        let out = Pipe(), err = Pipe()
        process.standardOutput = out
        process.standardError = err
        try process.run()
        let outData = out.fileHandleForReading.readDataToEndOfFile()
        let errData = err.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (String(decoding: outData, as: UTF8.self),
                String(decoding: errData, as: UTF8.self),
                process.terminationStatus)
    }
}

public struct DefaultPeripheryRunner: PeripheryRunner {
    public init() {}
    public func scanJSON(passthroughArgs: [String]) throws -> String {
        let result = try Subprocess.run("periphery", ["scan", "--format", "json"] + passthroughArgs)
        if result.code == 127 { throw DeadwoodError.peripheryNotFound }
        guard result.code == 0 else { throw DeadwoodError.peripheryFailed(stderr: result.stderr) }
        return result.stdout
    }
}

public struct DefaultGitDiffProvider: GitDiffProvider {
    public init() {}
    public func unifiedDiff(since: String) throws -> String {
        let result = try Subprocess.run("git", ["diff", "--unified=0", since])
        guard result.code == 0 else { throw DeadwoodError.gitFailed(stderr: result.stderr) }
        return result.stdout
    }
}
