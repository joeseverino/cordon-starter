#!/usr/bin/env bash
# check.sh — THE verification gate. One definition; the pre-push hook, CI
# (`--ci`), you, and an AI all run this exact script, so local and CI can't drift.
#
#   (no flag)   full   shellcheck + contract drift + schema conformance
#   --fast             shellcheck + contract drift   (skips conformance; inner loop)
#   --ci               shellcheck + schema conformance (no toolchain; ci.yml runs this)
#   --env              report environment wiring; run no checks
#   -h, --help         this help
#
# Step × mode (defined once, below):
#                       full  --fast  --ci
#   lint (shellcheck)     ✓      ✓      ✓
#   contract drift*       ✓      ✓      —    (*re-emits --describe; needs $TOOLS_HOME)
#   schema conformance**  ✓      —      ✓    (**validates via cordon's own harness)
set -euo pipefail
cd "$(dirname "$0")/.."

usage() { sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; }

MODE=full
case "${1:-}" in
    --fast) MODE=fast ;;
    --ci)   MODE=ci ;;
    --env)  MODE="env" ;;
    -h|--help) usage; exit 0 ;;
    "") ;;
    *) echo "unknown option: $1 (try --help)" >&2; exit 2 ;;
esac

fail=0

# ---- single definitions every mode and CI share ----------------------------
SHELLCHECK_TARGETS=(bin/* scripts/*.sh .githooks/*)
# Reference cordon itself, never a vendored copy. Local: $CORDON_HOME from
# ~/.zshrc (falls back to $ASSETS_HOME/cordon). CI: the workflow checks out the
# public cordon repo and points $CORDON_HOME at it. Either way the schema AND
# the validator are cordon's real, current files.
CORDON_HOME="${CORDON_HOME:-${ASSETS_HOME:+$ASSETS_HOME/cordon}}"
HARNESS="${CORDON_HOME:+$CORDON_HOME/conformance/validate.mjs}"

run_shellcheck() {
    echo "== shellcheck =="
    if command -v shellcheck >/dev/null 2>&1; then
        if shellcheck -x "${SHELLCHECK_TARGETS[@]}"; then echo "  ok"; else fail=1; fi
    else
        echo "  skipped — shellcheck not installed (brew install shellcheck)"
    fi
}

run_drift() {
    echo "== contract drift =="
    local tool name golden
    for tool in bin/*; do
        [[ -x "$tool" ]] || continue
        name="$(basename "$tool")"
        golden="contract/$name.json"
        if [[ ! -f "$golden" ]]; then
            echo "  MISSING $golden — generate it: $tool --describe > $golden"; fail=1; continue
        fi
        if "$tool" --describe | diff -u "$golden" - >/dev/null 2>&1; then
            echo "  ok: $name"
        else
            echo "  DRIFT: $name --describe != $golden  (regenerate: $tool --describe > $golden)"; fail=1
        fi
    done
}

run_conformance() {
    echo "== schema conformance (cordon's harness) =="
    local golden
    if [[ -z "$HARNESS" || ! -f "$HARNESS" ]]; then
        if [[ "$MODE" == ci ]]; then
            echo "  FAIL — cordon harness not found (\$CORDON_HOME=${CORDON_HOME:-<unset>})" >&2; fail=1
        else
            echo "  skipped — \$CORDON_HOME not reachable (${CORDON_HOME:-<unset>}); CI validates via cordon"
        fi
        return
    fi
    for golden in contract/*.json; do
        [[ -f "$golden" ]] || continue
        node "$HARNESS" "$golden" || fail=1   # harness prints ✓/✗ and sets the exit code
    done
}

run_env() {
    echo "== environment =="
    _have() { command -v "$1" >/dev/null 2>&1 && echo yes || echo no; }
    echo "  TOOLS_HOME            : ${TOOLS_HOME:-<unset>}"
    echo "  describe.sh reachable : $([[ -f "${TOOLS_HOME:-}/lib/describe.sh" ]] && echo yes || echo no)"
    echo "  CORDON_HOME           : ${CORDON_HOME:-<unset>}"
    echo "  cordon harness        : $([[ -n "$HARNESS" && -f "$HARNESS" ]] && echo yes || echo no)"
    echo "  shellcheck            : $(_have shellcheck)"
    echo "  node                  : $(_have node)"
    echo "  hooks (core.hooksPath): $(git config core.hooksPath 2>/dev/null || echo '<unset — run scripts/setup-hooks.sh>')"
}

case "$MODE" in
    full) run_shellcheck; run_drift; run_conformance ;;
    fast) run_shellcheck; run_drift ;;
    ci)   run_shellcheck; run_conformance ;;
    env)  run_env; exit 0 ;;
esac

if [[ $fail -eq 0 ]]; then echo "ALL GREEN ($MODE)"; else echo "FAILURES ($MODE) — fix before pushing" >&2; fi
exit $fail
