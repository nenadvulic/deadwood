import ArgumentParser
import DeadwoodCore
import Foundation

extension ReportFormat: ExpressibleByArgument {}

@main
struct Deadwood: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "deadwood",
        abstract: "Report the dead code a change introduces, scoped to the git diff (powered by Periphery)."
    )

    @Option(name: .long, help: "git diff spec to scope against (ref like HEAD, or a range like origin/main...HEAD).")
    var since: String = "HEAD"

    @Option(name: [.customLong("format"), .short], help: "Output format: text (default) or json.")
    var format: ReportFormat = .text

    @Flag(name: .customLong("no-fail"), help: "Always exit 0, even when new dead code is found.")
    var noFail = false

    @Argument(parsing: .allUnrecognized,
              help: "Arguments passed through to `periphery scan` (after --).")
    var peripheryArgs: [String] = []

    func run() throws {
        let engine = DeadwoodEngine(runner: DefaultPeripheryRunner(), diffProvider: DefaultGitDiffProvider())
        let cleanedArgs = peripheryArgs.filter { $0 != "--" }
        do {
            let result = try engine.run(since: since, format: format, peripheryArgs: cleanedArgs)
            print(result.report)
            if result.hasFindings && !noFail { throw ExitCode.failure }
        } catch let error as DeadwoodError {
            FileHandle.standardError.write(Data("deadwood: \(error.description)\n".utf8))
            throw ExitCode.failure
        }
    }
}
