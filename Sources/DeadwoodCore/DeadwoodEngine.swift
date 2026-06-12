import Foundation

public struct DeadwoodEngine {
    private let runner: PeripheryRunner
    private let diffProvider: GitDiffProvider

    public init(runner: PeripheryRunner, diffProvider: GitDiffProvider) {
        self.runner = runner
        self.diffProvider = diffProvider
    }

    public func run(since: String, format: ReportFormat, peripheryArgs: [String]) throws
        -> (report: String, hasFindings: Bool)
    {
        let json = try runner.scanJSON(passthroughArgs: peripheryArgs)
        let results = try JSONDecoder().decode([PeripheryResult].self, from: Data(json.utf8))
        let diff = DiffRanges.parse(unifiedDiff: try diffProvider.unifiedDiff(since: since))
        let scoped = Scoper.scope(results, to: diff)
        return (Reporter.render(scoped, format: format), !scoped.isEmpty)
    }
}
