#!/usr/bin/env bash
# try.sh — kick the tires on this scaffold. An agent (or a human) can call this
# to SEE the emit-once contract work end to end before touching anything. It
# prints the contract and runs the example tool; nothing here is destructive.
set -euo pipefail
cd "$(dirname "$0")/.."

# The example tool sources the canonical describe.sh from the toolchain. Honor
# $TOOLS_HOME from ~/.zshrc; fall back to the standard location for a bare shell.
: "${TOOLS_HOME:=${ASSETS_HOME:-$HOME/Documents/Code/Assets}/tools}"
export TOOLS_HOME

hr() { printf '\n\033[1m── %s ──\033[0m\n' "$1"; }

hr "1. human help  (rendered from describe_spec)"
./bin/example-tool -h

hr "2. machine contract  (--describe — risk-gate on .effect)"
./bin/example-tool --describe --pretty 2>/dev/null || ./bin/example-tool --describe

hr "3. dry run  (mutates nothing)"
./bin/example-tool -n widget

hr "4. real run"
./bin/example-tool widget

hr "5. gate  (shellcheck + contract drift + schema conformance)"
./scripts/check.sh

hr "done"
echo "Next: edit bin/example-tool's describe_spec, then regenerate the golden:"
echo "  ./bin/example-tool --describe > contract/example-tool.json"
