#!/usr/bin/env bash
# ensure-cordon.sh — make the cordon harness reachable, fetching it once if
# absent so a fresh clone's gate and hooks just work with no manual env wiring.
# Resolves CORDON_HOME exactly as check.sh does, and when the engine isn't there
# it delegates to cordon's own install.sh (clone + wire CORDON_HOME into ~/.zshrc,
# with a backup). Idempotent: a no-op when cordon is already present.
#
# Prints the resolved CORDON_HOME on stdout (progress goes to stderr), so a caller
# can:  export CORDON_HOME="$(scripts/ensure-cordon.sh)"
set -euo pipefail

INSTALL_URL="${CORDON_INSTALL_URL:-https://raw.githubusercontent.com/joeseverino/cordon/main/install.sh}"
CORDON_HOME="${CORDON_HOME:-${ASSETS_HOME:-$HOME/Documents/Code/Assets}/cordon}"
export CORDON_HOME   # install.sh reads it to clone into the same place check.sh expects

if [ ! -f "$CORDON_HOME/checks/run.mjs" ]; then
  echo "cordon not found — fetching it once into $CORDON_HOME" >&2
  command -v git >/dev/null 2>&1 || { echo "git not found — install git, or set CORDON_HOME to an existing cordon checkout" >&2; exit 1; }
  command -v curl >/dev/null 2>&1 || { echo "curl not found — install curl, or set CORDON_HOME to an existing cordon checkout" >&2; exit 1; }
  curl -fsSL "$INSTALL_URL" | bash >&2
  [ -f "$CORDON_HOME/checks/run.mjs" ] || { echo "cordon fetch did not land the engine at $CORDON_HOME" >&2; exit 1; }
fi

printf '%s\n' "$CORDON_HOME"
