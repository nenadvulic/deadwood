#!/usr/bin/env bash
# Snapshot tests for ci/render.sh. Diffs render output against ci/tests/expected/.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
RENDER="$HERE/../render.sh"
FIX="$HERE/fixtures"
EXP="$HERE/expected"
fail=0

# Per-run temp file for diff output (avoid collisions when tests run in parallel or in nested shells).
DIFF_TMP=$(mktemp)
trap 'rm -f "$DIFF_TMP"' EXIT

check() {  # check <fixture> <target> <expected-file> [extra render args...]
  local fixture="$1" target="$2" expected="$3"; shift 3
  local got
  got="$("$RENDER" "$target" "$@" < "$FIX/$fixture")"
  if ! diff -u "$EXP/$expected" <(printf '%s\n' "$got") >"$DIFF_TMP" 2>&1; then
    echo "FAIL: $fixture → $target"; cat "$DIFF_TMP"; fail=1
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

# markdown + gitlab with --repo-root stripping (abspath fixture)
check abspath.json markdown abspath.markdown --repo-root /Users/ci/work/repo

check_gitlab() {  # check_gitlab <fixture> <expected> [extra args...]
  local fixture="$1" expected="$2"; shift 2
  local got
  got="$("$RENDER" gitlab "$@" < "$FIX/$fixture" | jq -S '(.[].fingerprint) = "FP"')"
  if ! diff -u "$EXP/$expected" <(printf '%s\n' "$got") >"$DIFF_TMP" 2>&1; then
    echo "FAIL: $fixture → gitlab"; cat "$DIFF_TMP"; fail=1
  else
    echo "PASS: $fixture → gitlab"
  fi
}
check_gitlab one.json  one.gitlab
check_gitlab many.json many.gitlab
check_gitlab abspath.json abspath.gitlab --repo-root /Users/ci/work/repo
check_gitlab empty.json   empty.gitlab

# github on empty.json → no output
check empty.json github empty.github

# Fingerprints must be stable across runs and unique per finding.
# Expected hashes are shasum of usrs[0] for each finding in many.json:
#   finding 0: printf '%s' "s:3App10unusedHelperyyF" | shasum | cut -d' ' -f1
#   finding 1: printf '%s' "s:3App9staleFlagSbvp"    | shasum | cut -d' ' -f1
FP_EXPECTED_0="3d674dfd37c05f5ff2ec19ef781c9606e889f6ba"
FP_EXPECTED_1="118701064abf9d803a89ed3bf9ba7ab94de038ea"
fp_actual=$("$RENDER" gitlab < "$FIX/many.json" | jq -r '.[].fingerprint')
fp_expected=$(printf '%s\n%s' "$FP_EXPECTED_0" "$FP_EXPECTED_1")
if [ "$fp_actual" != "$fp_expected" ]; then
  echo "FAIL: fingerprint not stable (regression in fingerprint algorithm)"
  echo "  expected: $fp_expected"
  echo "  got:      $fp_actual"
  fail=1
else
  echo "PASS: fingerprint stable"
fi
if [ "$(printf '%s\n' "$fp_actual" | sort -u | wc -l | tr -d ' ')" != "2" ]; then echo "FAIL: fingerprints not unique"; fail=1; else echo "PASS: fingerprints unique"; fi

# Empty-usrs fallback fingerprint: key is "file:line:kind:name".
# Expected: printf '%s' "Sources/App/Checkout.swift:42:function:unusedHelper()" | shasum | cut -d' ' -f1
FP_NOUSR_EXPECTED="fa4ead60d2a91df003cd19ef315ba8312f9a6c5b"
fp_nousr=$("$RENDER" gitlab < "$FIX/nousr.json" | jq -r '.[0].fingerprint')
if [ "$fp_nousr" != "$FP_NOUSR_EXPECTED" ]; then
  echo "FAIL: nousr fallback fingerprint wrong (got: $fp_nousr)"
  fail=1
else
  echo "PASS: nousr fallback fingerprint"
fi

check verbose.json    github   verbose.github
check assignonly.json github   assignonly.github

# --- SARIF target ---
sarif_assert() {  # sarif_assert <label> <fixture> <jq-filter> <expected> [extra render args...]
  local label="$1" fixture="$2" filter="$3" expected="$4"; shift 4
  local got
  got="$("$RENDER" sarif "$@" < "$FIX/$fixture" | jq -r "$filter")"
  if [ "$got" != "$expected" ]; then
    echo "FAIL: sarif $label — got [$got] expected [$expected]"; fail=1
  else
    echo "PASS: sarif $label"
  fi
}
# valid JSON + schema/version/tool
sarif_assert "valid-json"   many.json '. | type'                                   object
sarif_assert "version"      many.json '.version'                                   2.1.0
sarif_assert "tool-name"    many.json '.runs[0].tool.driver.name'                  deadwood
sarif_assert "rule-id"      many.json '.runs[0].tool.driver.rules[0].id'           deadwood/unused-declaration
# results
sarif_assert "empty-count"  empty.json '.runs[0].results | length'                 0
sarif_assert "one-count"    one.json  '.runs[0].results | length'                  1
sarif_assert "many-count"   many.json '.runs[0].results | length'                  2
sarif_assert "level"        one.json  '.runs[0].results[0].level'                  warning
sarif_assert "ruleId"       one.json  '.runs[0].results[0].ruleId'                 deadwood/unused-declaration
sarif_assert "message"      one.json  '.runs[0].results[0].message.text'           "function 'unusedHelper()' is unused"
sarif_assert "uri"          one.json  '.runs[0].results[0].locations[0].physicalLocation.artifactLocation.uri' Sources/App/Checkout.swift
sarif_assert "line"         one.json  '.runs[0].results[0].locations[0].physicalLocation.region.startLine'     42
sarif_assert "fingerprint"  one.json  '.runs[0].results[0].partialFingerprints.deadwoodFingerprint'            3d674dfd37c05f5ff2ec19ef781c9606e889f6ba
# kind simplification + hint drop reused from gitlab logic
sarif_assert "verbose-msg"  verbose.json '.runs[0].results[0].message.text'        "method 'doThing()' is unused"
sarif_assert "assignonly-msg" assignonly.json '.runs[0].results[0].message.text'   "var 'cache' is unused — assignOnly"
# --repo-root strips the absolute prefix
sarif_assert "repo-root-uri" abspath.json '.runs[0].results[0].locations[0].physicalLocation.artifactLocation.uri' Sources/App/Checkout.swift --repo-root /Users/ci/work/repo

exit $fail
