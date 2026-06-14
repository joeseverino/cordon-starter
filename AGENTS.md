# AGENTS.md

This repo was started from **cordon-starter** — the canonical scaffold every
Severino repo begins from. The rules below are the standing cornerstones. They
override anything an older repo's docs imply.

> Rename the placeholders (`<repo>`, the example tool) and delete what a given
> project doesn't need. The cornerstones stay.

## How a command surface is documented here

The single source of truth for any CLI surface is **one shell declaration**, not
prose. A tool defines `describe_spec()` and the contract JSON is *emitted* from
it — the human help and the machine JSON are two pure renders of the same
declaration, so they cannot drift.

- **Reference implementation — the canonical "cordon zshrc":**
  `"$TOOLS_HOME/lib/describe.sh"` (`$TOOLS_HOME` is exported from `~/.zshrc`).
  Read that file's header and a real `describe_spec()` (e.g.
  `"$TOOLS_HOME/bin/encrypt"`) before writing or editing any command surface.
  Do **not** infer the contract shape from README prose.
- **The schema:** `https://jseverino.com/schemas/cordon-v4.json`
  (`schema_version: 4`). The contract is `additionalProperties: false` and
  byte-deterministic — no timestamps, stable ordering.
- **Effect ladder** (every tool/command declares one, default `read`):
  `read < local_write < vault_write < remote_write < deploy`, plus optional
  `+network` / `+interactive`. Declare it on anything that mutates, reaches
  off-box, or blocks on a TTY.

`bin/example-tool` in this starter is a working `describe_spec()` you can copy.

## Introspect via the contract, never by parsing source

To learn what a tool does, **call its contract** — `<tool> --describe` (or
`tools describe <name>` for the toolchain). Read the JSON; risk-gate on `effect`.
Do not read the implementation to reconstruct flags or behavior.

If a tool has **no `--describe`**, that is the bug: give it a `describe_spec()`
(source the canonical `describe.sh`), then call it. A surface without a contract
is unfinished.

## Git workflow — branch → PR → review → merge

Never commit to `main`. Never branch from a stale local tree.

```sh
git fetch origin
git checkout -b <feature> origin/main
# work, commit, push
gh pr create
```

- One feature = one branch name, reused across repos when the change spans them.
- Hand back only on **green CI** with **zero unresolved PR comments**.
- **Solo-authored.** No `Co-Authored-By`, no "Claude/AI" mentions in commits or
  PR bodies.

On a new repo, run `scripts/setup-governance.sh` to protect `main` (required
`ci` green, conversations resolved, admin bypass — you review and merge) and
switch on the security settings. Branch protection needs a public repo or
GitHub Pro; on a private free repo the script skips it and "never commit to
`main`" holds by discipline.

Make that discipline enforceable offline too: `scripts/setup-hooks.sh` points
git at the tracked `.githooks/` (`core.hooksPath`). `pre-commit` refuses commits
on `main`; `commit-msg` rejects AI attribution (the solo-authored rule above);
`pre-push` runs `scripts/check.sh` so red never leaves the machine. Bypass
deliberately with `ALLOW_MAIN_COMMIT=1` / `git … --no-verify`.

## CI and security

- `.github/workflows/ci.yml` runs **`scripts/check.sh --ci`** — the *same* gate
  the pre-push hook and you run, in its no-toolchain mode (shellcheck + schema
  conformance against the vendored `schema/cordon-v4.json`, frozen v4, no
  network). One definition, so CI and local can't drift.
- Add language-specific lint/scanners per the repo's narrative. Security-focused
  repos get a visible scanner (Semgrep/CodeQL) + badge; a plain CLI gets
  lint-only. See `docs/CORNERSTONES.md`.
- **Contract drift is a CI failure waiting to happen — catch it locally.** Run
  `scripts/check.sh` before pushing (`--fast` for a quick loop): it re-emits
  each tool's `--describe` and diffs it against the committed `contract/*.json`.
  Regenerate and commit the golden when the surface legitimately changes.

## Environment it assumes

These repos live in the Severino Code tree and read paths from `~/.zshrc`
(single source of truth — don't hardcode `$HOME/Documents/...`):

| var | is |
|---|---|
| `$CODE_HOME` | `~/Documents/Code` |
| `$PROJECTS_HOME` | `$CODE_HOME/Projects` |
| `$ASSETS_HOME` | `$CODE_HOME/Assets` |
| `$TOOLS_HOME` | `$ASSETS_HOME/tools` — the canonical `describe.sh` lives here |
| `$NOTES_HOME` | the Obsidian vault |

## Verify before handing back

```sh
scripts/check.sh        # shellcheck + contract drift + schema conformance
git diff --check        # no whitespace damage
```
