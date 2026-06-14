#!/usr/bin/env bash
# check.sh — local pre-push gate. Mirrors what CI enforces so red runs are
# caught before they leave the Mac: shellcheck, Cordon contract drift, and
# (when the canonical harness is present) schema conformance.
set -euo pipefail
cd "$(dirname "$0")/.."

fail=0

echo "== shellcheck =="
if command -v shellcheck >/dev/null 2>&1; then
    shellcheck -x bin/* scripts/*.sh && echo "  ok" || fail=1
else
    echo "  skipped — shellcheck not installed (brew install shellcheck)"
fi

echo "== contract drift =="
# Every bin/ tool's emitted --describe must equal its committed golden, so the
# JSON in version control is never stale relative to the shell declaration.
for tool in bin/*; do
    [[ -x "$tool" ]] || continue
    name="$(basename "$tool")"
    golden="contract/$name.json"
    if [[ ! -f "$golden" ]]; then
        echo "  MISSING $golden — generate it: $tool --describe > $golden"
        fail=1; continue
    fi
    if "$tool" --describe | diff -u "$golden" - >/dev/null 2>&1; then
        echo "  ok: $name"
    else
        echo "  DRIFT: $name --describe != $golden  (regenerate: $tool --describe > $golden)"
        fail=1
    fi
done

echo "== schema conformance =="
# Reuse the canonical cordon harness if it's checked out locally — don't vendor
# a copy. CI validates the same contracts against the published schema.
cordon="${CORDON_HOME:-${ASSETS_HOME:-$HOME/Documents/Code/Assets}/cordon}"
if [[ -f "$cordon/conformance/validate.mjs" ]]; then
    for golden in contract/*.json; do
        [[ -f "$golden" ]] || continue
        node "$cordon/conformance/validate.mjs" "$golden" && echo "  ok: $golden" || fail=1
    done
else
    echo "  skipped — cordon harness not at $cordon (CI validates against jseverino.com/schemas)"
fi

[[ $fail -eq 0 ]] && echo "ALL GREEN" || echo "FAILURES — fix before pushing"
exit $fail
