#!/usr/bin/env bash
#
# deadwood — Claude Code Stop hook
#
# When the agent finishes a turn, run deadwood on the working-tree diff and feed
# any newly-introduced dead code back so the agent removes it before stopping —
# instead of leaving the unused declaration its edit just created.
#
# Why a Stop hook (and not PostToolUse): deadwood drives Periphery, which does a
# full build + index. That is far too slow to run after every edit, so we run it
# once, at the end of the turn, when the agent thinks it's done.
#
# Wire it via .claude/settings.json:
#   "hooks": { "Stop": [ { "hooks": [ { "type": "command",
#     "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/deadwood-stop.sh" } ] } ] }
#
# Behaviour:
#   - already re-invoked by a prior Stop block (stop_hook_active) → exit 0
#     (we nudge once per turn; a Periphery loop is too expensive to risk)
#   - no .swift changed in the working tree, no .periphery.yml, or deadwood not
#     installed → exit 0 (silent no-op)
#   - Periphery/infra error (build broken, bad ref) → exit 0 (stay out of the way)
#   - new dead code found → print it on stderr, exit 2 (the agent sees it, fixes it)
#
# The binary is `deadwood` on PATH. Override with $DEADWOOD_BIN, e.g.
#   DEADWOOD_BIN="swift run --package-path /path/to/deadwood deadwood"
# to dogfood from a source checkout.
set -euo pipefail

DEADWOOD_BIN="${DEADWOOD_BIN:-deadwood}"

# 1. Read the hook payload. If we're already inside a Stop-triggered
#    continuation, don't block again — one Periphery run per turn is the budget.
payload="$(cat)"
if [ "$(printf '%s' "$payload" | jq -r '.stop_hook_active // false' 2>/dev/null || echo false)" = "true" ]; then
  exit 0
fi

# 2. Find the git repo root. Not a repo → nothing to diff against.
root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$root" ] || exit 0

# 3. Only act when the turn actually touched Swift sources (vs HEAD, staged or not).
if ! git -C "$root" diff --name-only HEAD 2>/dev/null | grep -q '\.swift$'; then
  exit 0
fi

# 4. The project must use Periphery (deadwood relies on its config discovery).
[ -f "$root/.periphery.yml" ] || exit 0

# 5. deadwood must be available, otherwise stay out of the way.
command -v "${DEADWOOD_BIN%% *}" >/dev/null 2>&1 || exit 0

# 6. Scope to the working-tree diff (the default --since HEAD). Capture stdout
#    (the findings report) and the exit code separately from stderr (errors).
set +e
report="$(cd "$root" && $DEADWOOD_BIN --since HEAD 2>/dev/null)"
code=$?
set -e

# 7. Clean (exit 0) → done. Infra error (exit != 0 but no report on stdout, e.g. a
#    build failure or missing Periphery) → stay out of the way.
[ "$code" -eq 0 ] && exit 0
[ -n "$report" ] || exit 0

# 8. New dead code: hand it to the agent and keep it working (exit 2).
{
  echo "deadwood found dead code introduced by this turn's changes:"
  echo
  echo "$report"
  echo
  echo "Remove the unused declaration(s) you just added — don't leave dead code behind. Prefer (in order):"
  echo "  1. Delete the declaration if nothing needs it."
  echo "  2. Wire it up if it was meant to be used (a forgotten call site)."
  echo "  3. If Periphery is wrong (protocol witness, @objc, reflection, public API), add a Periphery"
  echo "     '// periphery:ignore' comment or a .periphery.yml retain rule, with a reason."
} >&2
exit 2
