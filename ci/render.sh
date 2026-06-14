#!/usr/bin/env bash
# Pure renderer: deadwood JSON (stdin) → CI output (stdout). No network/Periphery/git.
# Usage: render.sh <github|gitlab|markdown> [--repo-root <abs-path>]
set -euo pipefail

TARGET="${1:-}"; shift || true
ROOT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --repo-root)
      if [ $# -lt 2 ] || [ -z "${2:-}" ]; then
        echo "render.sh: --repo-root requires a value" >&2; exit 2
      fi
      ROOT="$2"; shift 2 ;;
    *) echo "render.sh: unknown arg '$1'" >&2; exit 2 ;;
  esac
done

INPUT="$(cat)"
[ -n "$INPUT" ] || INPUT="[]"

# jq expression: rewrite .file to be repo-root-relative when --repo-root is given.
REL='(if $root != "" and (.file | startswith($root + "/")) then (.file | ltrimstr($root + "/")) else .file end)'

# jq fragment: collapse Periphery's verbose kind (e.g. function.method.instance) to a short label.
KIND='(.kind | if test("\\.method") then "method" else split(".")[0] end)'

markdown() {
  local n; n=$(jq 'length' <<<"$INPUT")
  if [ "$n" -eq 0 ]; then
    printf '%s\n%s\n' '<!-- deadwood-summary -->' '✅ **Deadwood** — no new dead code in this change.'
    return
  fi
  echo '<!-- deadwood-summary -->'
  echo "🪵 **Deadwood** — $n new dead declaration(s) introduced by this change:"
  echo
  jq -r --arg root "$ROOT" ".[] | ($REL) as \$f | ($KIND) as \$k | \"- \`\(\$f):\(.line)\` \(\$k) \`\(.name)\`\"" <<<"$INPUT"
  echo
  echo 'Remove them, or wire them up. If Periphery is wrong (protocol witness, @objc, reflection, public API), add a `// periphery:ignore` comment or a retain rule.'
}

# NOTE: $REL is a jq *fragment* interpolated into the jq program string; $root is passed safely via --arg (do not confuse them).
github() {
  jq -r --arg root "$ROOT" "
    .[] | ($REL) as \$f | ($KIND) as \$k |
    \"::warning file=\(\$f),line=\(.line),col=\(.column)::deadwood: \(\$k) '\(.name)' is unused\" +
    (if (.hints | length) > 0 and .hints[0] != \"unused\" then \" — \" + .hints[0] else \"\" end)
  " <<<"$INPUT"
}

# Stable fingerprint: prefer the USR (survives line moves); else path:line:kind:name.
fingerprint() { printf '%s' "$1" | shasum | cut -d' ' -f1; }

# NOTE: O(n) jq invocations (one per field + one append per finding). Accepted trade-off for CI-scale finding counts.
gitlab() {
  local n; n=$(jq 'length' <<<"$INPUT")
  local out='[]' i
  for ((i = 0; i < n; i++)); do
    local file line kind name hint0 usr key fp desc
    file=$(jq -r ".[$i].file" <<<"$INPUT")
    if [ -n "$ROOT" ] && [[ "$file" == "$ROOT/"* ]]; then file="${file#"$ROOT"/}"; fi
    line=$(jq -r ".[$i].line" <<<"$INPUT")
    kind=$(jq -r ".[$i] | $KIND" <<<"$INPUT")
    name=$(jq -r ".[$i].name" <<<"$INPUT")
    hint0=$(jq -r ".[$i].hints[0] // empty" <<<"$INPUT")
    usr=$(jq -r ".[$i].usrs[0] // empty" <<<"$INPUT")
    key="${usr:-$file:$line:$kind:$name}"  # fallback key assumes paths contain no embedded colons (true for Periphery macOS/Linux output)
    fp=$(fingerprint "$key")
    desc="$kind '$name' is unused"
    [ -n "$hint0" ] && [ "$hint0" != "unused" ] && desc="$desc — $hint0"
    out=$(jq --arg d "$desc" --arg fp "$fp" --arg p "$file" --argjson l "$line" \
      '. + [{description:$d, check_name:"deadwood/unused-declaration", fingerprint:$fp, severity:"minor", location:{path:$p, lines:{begin:$l}}}]' <<<"$out")
  done
  jq -S '.' <<<"$out"
}

# SARIF 2.1.0 (GitHub Code Scanning). Reuses $KIND + fingerprint() so the message
# matches the other targets. O(n) jq invocations, like gitlab — fine at CI scale.
sarif() {
  local n; n=$(jq 'length' <<<"$INPUT")
  local results='[]' i
  for ((i = 0; i < n; i++)); do
    local file line kind name hint0 usr key fp desc
    file=$(jq -r ".[$i].file" <<<"$INPUT")
    if [ -n "$ROOT" ] && [[ "$file" == "$ROOT/"* ]]; then file="${file#"$ROOT"/}"; fi
    line=$(jq -r ".[$i].line" <<<"$INPUT")
    kind=$(jq -r ".[$i] | $KIND" <<<"$INPUT")
    name=$(jq -r ".[$i].name" <<<"$INPUT")
    hint0=$(jq -r ".[$i].hints[0] // empty" <<<"$INPUT")
    usr=$(jq -r ".[$i].usrs[0] // empty" <<<"$INPUT")
    key="${usr:-$file:$line:$kind:$name}"
    fp=$(fingerprint "$key")
    desc="$kind '$name' is unused"
    [ -n "$hint0" ] && [ "$hint0" != "unused" ] && desc="$desc — $hint0"
    results=$(jq --arg d "$desc" --arg fp "$fp" --arg p "$file" --argjson l "$line" \
      '. + [{
        ruleId: "deadwood/unused-declaration",
        level: "warning",
        message: {text: $d},
        locations: [{physicalLocation: {artifactLocation: {uri: $p}, region: {startLine: $l}}}],
        partialFingerprints: {deadwoodFingerprint: $fp}
      }]' <<<"$results")
  done
  jq -Sn --argjson results "$results" '{
    "$schema": "https://json.schemastore.org/sarif-2.1.0.json",
    version: "2.1.0",
    runs: [{
      tool: {driver: {
        name: "deadwood",
        informationUri: "https://github.com/nenadvulic/deadwood",
        rules: [{id: "deadwood/unused-declaration", name: "UnusedDeclaration", shortDescription: {text: "Unused declaration introduced by this change"}}]
      }},
      results: $results
    }]
  }'
}

case "$TARGET" in
  markdown) markdown ;;
  github)   github ;;
  gitlab)   gitlab ;;
  sarif)    sarif ;;
  *) echo "render.sh: target must be one of github|gitlab|markdown|sarif" >&2; exit 2 ;;
esac
