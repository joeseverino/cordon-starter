#!/usr/bin/env bash
# check.sh — THE verification gate. One definition; the pre-push hook, CI
# (`--ci`), you, and an AI all run this exact script, so local and CI can't drift.
#
#   modes (which checks run):
#     (default)   full    shellcheck + contract drift + README + conformance + repo checks
#     --fast              shellcheck + contract drift + README       (inner loop; needs $TOOLS_HOME)
#     --ci                shellcheck + README + conformance + repo checks  (no toolchain; ci.yml)
#     --env               report environment wiring; run no checks
#   output:
#     (default)           compact — one line per check
#     -v, --verbose       expanded — headers, captions, sub-tool output (try.sh uses this)
#     --json              machine-readable result object (for an AI)
#     -h, --help          this help
set -euo pipefail
# Resolve our own dir to an absolute path BEFORE any cd, so sourcing and $0
# reads work no matter where we're invoked from (repo root, scripts/, abs path).
here="$(cd "$(dirname "$0")" && pwd)"; self="$here/$(basename "$0")"
# shellcheck source=scripts/_lib.sh
source "$here/_lib.sh"   # in-repo presentation; no external dependency
cd "$here/.."

usage() { sed -n '2,14p' "$self" | sed 's/^# \{0,1\}//'; }

MODE=full STYLE=compact
while [[ $# -gt 0 ]]; do
    case "$1" in
        --fast)              MODE=fast ;;
        --ci)                MODE=ci ;;
        --env)               MODE="env" ;;
        -v|--verbose)        STYLE=expanded ;;
        --json)              STYLE=json ;;
        -h|--help)           usage; exit 0 ;;
        *) echo "unknown option: $1 (try --help)" >&2; exit 2 ;;
    esac
    shift
done

fail=0
declare -a RES_NAME RES_STATUS RES_NOTE   # accumulated for --json + the summary

# ---- single definitions every mode and CI share ----------------------------
SHELLCHECK_TARGETS=(bin/* scripts/*.sh .githooks/*)
# Reference cordon itself, never a vendored copy. Local: $CORDON_HOME from
# ~/.zshrc (falls back to $ASSETS_HOME/cordon). CI: the workflow checks out the
# public cordon repo and points $CORDON_HOME at it. Either way the schema AND
# the validator are cordon's real, current files.
CORDON_HOME="${CORDON_HOME:-${ASSETS_HOME:+$ASSETS_HOME/cordon}}"
HARNESS="${CORDON_HOME:+$CORDON_HOME/conformance/validate.mjs}"
CHECKS="${CORDON_HOME:+$CORDON_HOME/checks/run.mjs}"

json_escape() {  # minimal JSON string escaper — no jq/node dependency
    local s="$1"; s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; s="${s//$'\n'/\\n}"; s="${s//$'\t'/\\t}"
    printf '%s' "$s"
}

# report <label> <caption> <status> <note> <detail> — the one rendering point.
# Every check funnels through here; STYLE decides how it looks. <detail> is the
# captured sub-tool output: shown always when expanded, on failure when compact,
# never when json.
report() {
    local label="$1" caption="$2" status="$3" note="$4" detail="$5"
    RES_NAME+=("$label"); RES_STATUS+=("$status"); RES_NOTE+=("$note")
    [[ "$status" == fail ]] && fail=1
    case "$STYLE" in
        compact)
            cline "$status" "$label" "$note"
            [[ "$status" == fail && -n "$detail" ]] && printf '%s\n' "$detail" ;;
        expanded)
            section "$label" "$caption"
            [[ -n "$detail" ]] && printf '%s\n' "$detail"
            case "$status" in
                pass) printf '   %s✓ ok%s\n'   "$GR" "$R" ;;
                skip) printf '   %s○ skip%s%s\n' "$YE" "$R" "${note:+ — $D$note$R}" ;;
                fail) printf '   %s✗ fail%s\n' "$RD" "$R" ;;
            esac ;;
        json) : ;;   # accumulated only; emitted once in finish()
    esac
    return 0   # never let a trailing &&-false abort the caller under set -e
}

# ---- the checks. Each runs its work, captures sub-output, calls report once --
run_shellcheck() {
    local cap="lint every bin/, script, and hook" out
    if ! command -v shellcheck >/dev/null 2>&1; then
        report shellcheck "$cap" skip "shellcheck not installed (brew install shellcheck)" ""; return
    fi
    if out="$(shellcheck -x "${SHELLCHECK_TARGETS[@]}" 2>&1)"; then
        report shellcheck "$cap" pass "" "$out"
    else
        report shellcheck "$cap" fail "" "$out"
    fi
}

run_drift() {
    local cap="committed golden == live --describe" detail="" status=pass tool name golden d
    for tool in bin/*; do
        [[ -x "$tool" ]] || continue
        name="$(basename "$tool")"; golden="contract/$name.json"
        if [[ ! -f "$golden" ]]; then
            status=fail; detail+="MISSING $golden — generate it: $tool --describe > $golden"$'\n'; continue
        fi
        if d="$("$tool" --describe | diff -u "$golden" - 2>&1)"; then
            detail+="ok: $name"$'\n'
        else
            status=fail; detail+="DRIFT: $name --describe != $golden (regenerate: $tool --describe > $golden)"$'\n'"$d"$'\n'
        fi
    done
    report "contract drift" "$cap" "$status" "" "${detail%$'\n'}"
}

run_readme() {
    # Renders the README CLI reference from the committed contract/*.json — Node
    # stdlib only, no $TOOLS_HOME, no deps — so it runs in every mode incl. --ci.
    local cap="README CLI reference == contract (gen-readme.mjs --check)" out
    if out="$(node scripts/gen-readme.mjs --check 2>&1)"; then report "README reference" "$cap" pass "" "$out"
    else report "README reference" "$cap" fail "" "$out"; fi
}

run_conformance() {
    local cap="every contract validates against cordon's schema" detail="" status=pass golden out
    if [[ -z "$HARNESS" || ! -f "$HARNESS" ]]; then
        if [[ "$MODE" == ci ]]; then
            report "schema conformance" "$cap" fail "cordon harness not found (\$CORDON_HOME=${CORDON_HOME:-<unset>})" ""
        else
            report "schema conformance" "$cap" skip "\$CORDON_HOME not reachable; CI validates via cordon" ""
        fi
        return
    fi
    # The harness needs its own deps (ajv). If cordon's node_modules is missing
    # (fresh checkout, or an iCloud conflict-copy ate the symlink) Node throws a
    # raw ERR_MODULE_NOT_FOUND that looks like cordon is broken — report it
    # actionably instead. CI installs cordon's deps, so there it's a hard fail.
    if ! (cd "$CORDON_HOME" && node --input-type=module -e "import 'ajv/dist/2020.js'") >/dev/null 2>&1; then
        local hint="cordon's deps aren't installed — run: (cd \"$CORDON_HOME\" && npm ci)"
        if [[ "$MODE" == ci ]]; then report "schema conformance" "$cap" fail "$hint" ""
        else report "schema conformance" "$cap" skip "$hint" ""; fi
        return
    fi
    for golden in contract/*.json; do
        [[ -f "$golden" ]] || continue
        if out="$(node "$HARNESS" "$golden" 2>&1)"; then detail+="$out"$'\n'
        else status=fail; detail+="$out"$'\n'; fi
    done
    report "schema conformance" "$cap" "$status" "" "${detail%$'\n'}"
}

run_checks() {
    local cap="repo invariants via cordon's checks runner" out
    if [[ -z "$CHECKS" || ! -f "$CHECKS" ]]; then
        if [[ "$MODE" == ci ]]; then
            report "repo checks" "$cap" fail "cordon checks runner not found (\$CORDON_HOME=${CORDON_HOME:-<unset>})" ""
        else
            report "repo checks" "$cap" skip "\$CORDON_HOME not reachable; CI runs them via cordon" ""
        fi
        return
    fi
    if out="$(node "$CHECKS" --root "$PWD" 2>&1)"; then report "repo checks" "$cap" pass "" "$out"
    else report "repo checks" "$cap" fail "" "$out"; fi
}

run_env() {
    section "environment" "how this clone is wired"
    _have() { command -v "$1" >/dev/null 2>&1 && echo yes || echo no; }
    echo "  TOOLS_HOME            : ${TOOLS_HOME:-<unset>}"
    echo "  describe.sh reachable : $([[ -f "${TOOLS_HOME:-}/lib/describe.sh" ]] && echo yes || echo no)"
    echo "  CORDON_HOME           : ${CORDON_HOME:-<unset>}"
    echo "  cordon harness        : $([[ -n "$HARNESS" && -f "$HARNESS" ]] && echo yes || echo no)"
    echo "  cordon checks runner  : $([[ -n "$CHECKS" && -f "$CHECKS" ]] && echo yes || echo no)"
    echo "  shellcheck            : $(_have shellcheck)"
    echo "  node                  : $(_have node)"
    echo "  hooks (core.hooksPath): $(git config core.hooksPath 2>/dev/null || echo '<unset — run scripts/setup-hooks.sh>')"
}

print_json() {
    local i n="${#RES_NAME[@]}" ok=true
    [[ $fail -eq 0 ]] || ok=false
    printf '{\n  "ok": %s,\n  "mode": "%s",\n  "checks": [\n' "$ok" "$MODE"
    for ((i = 0; i < n; i++)); do
        printf '    { "name": "%s", "status": "%s"' "$(json_escape "${RES_NAME[$i]}")" "${RES_STATUS[$i]}"
        [[ -n "${RES_NOTE[$i]}" ]] && printf ', "note": "%s"' "$(json_escape "${RES_NOTE[$i]}")"
        printf ' }%s\n' "$([[ $i -lt $((n - 1)) ]] && echo ,)"
    done
    printf '  ]\n}\n'
}

finish() {
    if [[ "$STYLE" == json ]]; then print_json; return; fi
    if [[ $fail -eq 0 ]]; then allgreen "$MODE"; else failures "$MODE" >&2; fi
}

case "$MODE" in
    full) run_shellcheck; run_drift; run_readme; run_conformance; run_checks ;;
    fast) run_shellcheck; run_drift; run_readme ;;
    ci)   run_shellcheck; run_readme; run_conformance; run_checks ;;
    env)  run_env; exit 0 ;;
esac

finish
exit $fail
