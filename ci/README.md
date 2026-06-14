# Deadwood in CI

Deadwood runs [Periphery](https://github.com/peripheryapp/periphery) once on a PR/MR,
keeps only the dead code your change introduced (diff-scoped), and reports it inline
plus as a sticky summary. **Requires a macOS runner** — Periphery does a full build + index.

## GitHub

```yaml
name: Dead code
on: pull_request
permissions:
  contents: read
  pull-requests: write
jobs:
  deadwood:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }
      - uses: nenadvulic/deadwood@v1
        with:
          working-directory: .
          # periphery-args: "--project App.xcodeproj --schemes App"
```

Inputs: `base`, `working-directory`, `periphery-args`, `fail-on-findings` (default `true`),
`comment` (default `true`), `periphery-version`.

### Example output (annotations)

```
::warning file=Sources/App/Checkout.swift,line=42,col=10::deadwood: function 'unusedHelper()' is unused
```

### Example output (sticky PR comment)

> 🪵 **Deadwood** — 2 new dead declaration(s) introduced by this change:
>
> - `Sources/App/Checkout.swift:42` function `unusedHelper()`
> - `Sources/App/Cart.swift:17` var `staleFlag`
>
> Remove them, or wire them up. If Periphery is wrong (protocol witness, @objc, reflection, public API), add a `// periphery:ignore` comment or a retain rule.

## GitLab

```yaml
include:
  - remote: 'https://raw.githubusercontent.com/nenadvulic/deadwood/v1/templates/deadwood.gitlab-ci.yml'
```

Runs on merge requests, on a runner tagged `macos`. Emits a Code Quality report
(shown inline in the MR diff and the widget). Set `DEADWOOD_GITLAB_TOKEN` (a token
with `api` scope) to also post a sticky MR note — `CI_JOB_TOKEN` cannot post notes.

Variables: `DEADWOOD_WORKDIR`, `DEADWOOD_PERIPHERY_ARGS`, `DEADWOOD_FAIL_ON_FINDINGS`, `DEADWOOD_GITLAB_TOKEN`.

### Example output (Code Quality report)

```json
[
  {
    "check_name": "deadwood/unused-declaration",
    "description": "function 'unusedHelper()' is unused",
    "fingerprint": "3d674dfd37c05f5ff2ec19ef781c9606e889f6ba",
    "location": {
      "lines": {
        "begin": 42
      },
      "path": "Sources/App/Checkout.swift"
    },
    "severity": "minor"
  }
]
```

## How it works

One `deadwood --format json --no-fail` run → `ci/render.sh` transforms the JSON into
GitHub annotations, a GitLab Code Quality report, or the shared markdown summary.
The renderer is pure (bash + jq) and snapshot-tested under `ci/tests/`.

## Cost & cadence

Periphery does a **full build + index** of the package on every run — that is the
expensive part, measured in (tens of) seconds to minutes on real projects, not
milliseconds. Deadwood runs it **once** per job and derives every output from that
single run, but the run itself is not cheap.

So pick the cadence deliberately:

- **CI** — run on **pull/merge requests**, not on every push to every branch. The
  templates here already gate on `pull_request` / `merge_request_event`. The build
  caching (`actions/cache` on `.build`) keeps deadwood's own compile warm; Periphery's
  project build is the remaining cost.
- **Local / agents** — don't run it per keystroke or per file edit. The companion
  Claude Code hook is a **`Stop` hook** (once when the agent finishes a turn), not a
  `PostToolUse` hook, for exactly this reason.

If a job feels slow, that's Periphery indexing the project — expected, not a Deadwood
overhead.
