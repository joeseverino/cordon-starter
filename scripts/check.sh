#!/usr/bin/env bash
# check.sh — local pre-push gate. Mirrors what CI enforces so red runs are
# caught before they leave the Mac: shellcheck, Cordon contract drift, and
# (when the canonical harness is present) schema conformance.
set -euo pipefail
cd "$(dirname "$0")/.."

fail=0

echo "== shellcheck =="
if command -v shellcheck >/dev/null 2>&1; then
    shellcheck -x bin/* scripts/*.sh .githooks/* && echo "  ok" || fail=1
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
# Prefer the canonical cordon harness if it's checked out locally; otherwise
# validate against the vendored frozen schema with ajv. Either way the contract
# is checked against cordon-v4 — CI does the same with the vendored schema.
cordon="${CORDON_HOME:-${ASSETS_HOME:+$ASSETS_HOME/cordon}}"
if [[ -n "$cordon" && -f "$cordon/conformance/validate.mjs" ]]; then
    for golden in contract/*.json; do
        [[ -f "$golden" ]] || continue
        node "$cordon/conformance/validate.mjs" "$golden" && echo "  ok: $golden" || fail=1
    done
elif command -v ajv >/dev/null 2>&1; then
    for golden in contract/*.json; do
        [[ -f "$golden" ]] || continue
        if ajv validate --spec=draft2020 -s schema/cordon-v4.json -d "$golden" >/dev/null 2>&1; then
            echo "  ok: $golden (vendored schema)"
        else
            echo "  INVALID: $golden"; fail=1
        fi
    done
else
    echo "  skipped — no cordon harness, no ajv. CI validates against schema/cordon-v4.json."
fi

[[ $fail -eq 0 ]] && echo "ALL GREEN" || echo "FAILURES — fix before pushing"
exit $fail
