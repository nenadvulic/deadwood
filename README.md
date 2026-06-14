# Deadwood

Report the dead code a change introduces,  scoped to your git diff, powered by [Periphery](https://github.com/peripheryapp/periphery).

Periphery finds unused declarations across the whole project. Deadwood runs it, then keeps only the findings located in the lines your change touched, so you see *what this PR/commit made dead*, not a wall of pre-existing debt.

## Requirements

- [Periphery](https://github.com/peripheryapp/periphery) installed and configured (a `.periphery.yml`, or pass its args after `--`).

## Usage

```bash
# Dead code introduced by your working-tree changes:
deadwood

# Dead code introduced by a branch vs its base (CI/PR):
deadwood --since origin/main...HEAD

# JSON output:
deadwood --format json

# Pass arguments through to `periphery scan`:
deadwood -- --project App.xcodeproj --schemes App
```

Exit code is `1` when new dead code is found (so it can gate CI), `0` otherwise. Use `--no-fail` to always exit `0`.

## How it works

`periphery scan --format json` → keep findings whose location falls in the changed lines of `git diff --unified=0 <since>` → report (text/json).

## CI

Run Deadwood on every pull/merge request, on a macOS runner. It reports the
newly-introduced dead code where reviewers (and AI agents) already look:

- **GitHub** — inline `::warning` annotations, a sticky PR summary comment, and an
  optional **SARIF 2.1.0** report. Set the action's `sarif-file` input and upload it
  with `github/codeql-action/upload-sarif`, and findings show up in **Security ▸ Code
  scanning** — deduplicated and tracked over time (not just in the run log).
- **GitLab** — a Code Quality report (shown inline in the MR diff) plus a sticky MR note.

See [ci/README.md](ci/README.md) for the GitHub Action and the GitLab template.

## Direction & roadmap

Deadwood is an **agent-native dead-code guardrail** built *on top of* Periphery — the goal isn't a new detector (Periphery's semantic index is the engine) but to put its findings exactly where code is written and reviewed: in front of AI agents as they edit, and in CI on every PR/MR.

- ✅ **Diff-scoped engine** — report only the dead code a change introduces, not pre-existing debt.
- ✅ **Agent hook** — a Claude Code Stop hook feeds newly-introduced dead code back to the agent so it cleans up before finishing (see [`.claude/`](.claude/)).
- ✅ **CI** — GitHub Action + GitLab template: inline findings (annotations / Code Quality report), a **SARIF** report for GitHub Code Scanning, plus a sticky PR/MR summary (see [`ci/`](ci/README.md)).
- 🔜 **Assisted removal** — once Periphery exposes each declaration's full source range, Deadwood can excise the dead declaration with SwiftSyntax (Periphery finds, Deadwood removes). Tracked upstream in [Periphery Discussion #1130](https://github.com/peripheryapp/periphery/discussions/1130).

The assisted-removal step is deliberately gated on [#1130](https://github.com/peripheryapp/periphery/discussions/1130): safe removal needs the declaration's exact source range from Periphery's output, so we're aligning with upstream rather than guessing ranges.

## License

MIT
