#!/usr/bin/env bash
# Snapshot tests for ci/render.sh. Diffs render output against ci/tests/expected/.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
RENDER="$HERE/../render.sh"
FIX="$HERE/fixtures"
EXP="$HERE/expected"
fail=0

check() {  # check <fixture> <target> <expected-file> [extra render args...]
  local fixture="$1" target="$2" expected="$3"; shift 3
  local got
  got="$("$RENDER" "$target" "$@" < "$FIX/$fixture")"
  if ! diff -u "$EXP/$expected" <(printf '%s\n' "$got") >/tmp/render-diff 2>&1; then
    echo "FAIL: $fixture → $target"; cat /tmp/render-diff; fail=1
  else
    echo "PASS: $fixture → $target"
  fi
}

check empty.json  markdown empty.markdown
check one.json    markdown one.markdown
check many.json   markdown many.markdown

check one.json    github   one.github
check many.json   github   many.github
check abspath.json github  abspath.github --repo-root /Users/ci/work/repo

check_gitlab() {  # check_gitlab <fixture> <expected> [extra args...]
  local fixture="$1" expected="$2"; shift 2
  local got
  got="$("$RENDER" gitlab "$@" < "$FIX/$fixture" | jq -S '(.[].fingerprint) = "FP"')"
  if ! diff -u "$EXP/$expected" <(printf '%s\n' "$got") >/tmp/render-diff 2>&1; then
    echo "FAIL: $fixture → gitlab"; cat /tmp/render-diff; fail=1
  else
    echo "PASS: $fixture → gitlab"
  fi
}
check_gitlab one.json  one.gitlab
check_gitlab many.json many.gitlab

# Fingerprints must be stable across runs and unique per finding.
fp() { "$RENDER" gitlab < "$FIX/$1" | jq -r '.[].fingerprint'; }
if [ "$(fp many.json)" != "$(fp many.json)" ]; then echo "FAIL: fingerprint not stable"; fail=1; else echo "PASS: fingerprint stable"; fi
if [ "$(fp many.json | sort -u | wc -l | tr -d ' ')" != "2" ]; then echo "FAIL: fingerprints not unique"; fail=1; else echo "PASS: fingerprints unique"; fi

exit $fail
