# deadwood — Claude Code integration

Runs deadwood automatically when an AI agent finishes a turn, so the dead code an
edit *introduces* gets caught and removed in the same session — the agent never
decides whether to check, and it doesn't get to stop while it has left an unused
declaration behind.

## Files

| File | Role |
|------|------|
| `hooks/deadwood-stop.sh` | Stop hook: runs deadwood on the working-tree diff at the end of the turn |
| `settings.json` | Wires the hook to the `Stop` event |

To adopt in another project, copy both files into its `.claude/` directory.

## Why a `Stop` hook (not `PostToolUse`)

deadwood drives [Periphery](https://github.com/peripheryapp/periphery), which does
a full build + index of the package. That is far too slow to run after every edit.
A `Stop` hook runs it **once**, when the agent thinks it's done — the right cadence
for an expensive whole-project analysis. (Contrast with an architecture linter like
`solid-like-a-rock`, which parses syntax only and is cheap enough for `PostToolUse`.)

## Activate

Claude Code only watches `.claude/settings.json` files that existed when the
session started. After copying the files into a running session, open `/hooks`
once (or restart Claude Code) so the hook is loaded. New sessions pick it up
automatically.

## What the agent sees when it leaves dead code

The hook runs deadwood, then exits non-zero so the diagnostics are fed back and the
agent keeps working until the diff is clean:

```
deadwood found dead code introduced by this turn's changes:

Sources/App/Checkout.swift:42:10: function 'unusedHelper()' is unused

Remove the unused declaration(s) you just added — don't leave dead code behind. Prefer (in order):
  1. Delete the declaration if nothing needs it.
  2. Wire it up if it was meant to be used (a forgotten call site).
  3. If Periphery is wrong (protocol witness, @objc, reflection, public API), add a Periphery
     '// periphery:ignore' comment or a .periphery.yml retain rule, with a reason.
```

It is a silent no-op when the turn changed no `.swift` files, the project has no
`.periphery.yml`, or deadwood is not installed — so it never blocks unrelated work.
A Periphery/infra error (a broken build, a bad ref) also stays out of the way: the
hook only blocks on actual findings, never on infrastructure failures.

## One nudge per turn (cost guard)

The hook respects Claude Code's `stop_hook_active` flag: once it has blocked and the
agent has continued, the **next** Stop is allowed through (exit 0) without re-running
Periphery. This bounds the cost — at most one Periphery build per turn — and avoids an
expensive loop when a finding can't be fully cleaned (e.g. a false positive the agent
can't suppress). Trade-off: if real dead code remains after the agent's one cleanup
attempt, the hook won't block a second time that turn; the next turn re-checks from scratch.

## Choosing the binary (`DEADWOOD_BIN`)

By default the hook calls `deadwood` on `PATH`. Override it to dogfood from a source
checkout that has no installed binary:

```bash
# in settings.json, set an env var for the command, or export it in your shell:
DEADWOOD_BIN="swift run --package-path /path/to/deadwood deadwood"
```

Note: `swift run` triggers its own build, on top of Periphery's — slower still. Prefer
an installed binary for day-to-day use.
