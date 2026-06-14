[![ci](https://github.com/joeseverino/cordon-starter/actions/workflows/ci.yml/badge.svg)](https://github.com/joeseverino/cordon-starter/actions/workflows/ci.yml)

# cordon-starter

The scaffold every Severino repo begins from. Lean enough to become any kind of
project, but it ships with the standing cornerstones already wired: the Cordon
emit-once command-surface contract, a green-gating CI, the branch→PR→review→merge
workflow, and one command that applies branch protection + repo security.

It is **not** a generator. It's a small, opinionated tree you copy and prune —
and the parts that would otherwise drift (the contract JSON, the `describe.sh`
machinery) are *sourced from your toolchain*, not vendored.

## Start a new repo from it

Quickest path: click **[Use this template](https://github.com/joeseverino/cordon-starter/generate)**
on GitHub for a fresh repo with clean history. Or copy the tree locally and prune:

```sh
cp -R "$PROJECTS_HOME/cordon-starter" "$PROJECTS_HOME/<repo>"
cd "$PROJECTS_HOME/<repo>"
rm -rf .git && git init -b main          # fresh history
scripts/setup-hooks.sh                    # local guardrails (block main, gate pushes) — works offline

# make it yours
mv bin/example-tool bin/<repo>           # rename the tool, rewrite describe_spec
$EDITOR AGENTS.md README.md              # delete what you don't need

bin/<repo> --describe > contract/<repo>.json   # generate the golden contract
scripts/check.sh                          # shellcheck + drift + conformance

git add -A && git commit -m "Initial commit"
gh repo create joeseverino/<repo> --private --source=. --push
scripts/setup-governance.sh               # protect main + security settings
```

From here on: `git fetch origin && git checkout -b <feature> origin/main`, never
commit to `main`. See [AGENTS.md](AGENTS.md).

## What's in the box

| path | what it is |
|---|---|
| `AGENTS.md` (+ `CLAUDE.md` symlink) | the cornerstone playbook — read first |
| `bin/example-tool` | a runnable Cordon-emitting tool; copy its `describe_spec()` |
| `contract/example-tool.json` | the committed golden contract (emitted, never hand-edited) |
| `.github/workflows/ci.yml` | shellcheck + Cordon schema conformance — the required `ci` check |
| `scripts/try.sh` | smoke test — run it to watch the contract work end to end |
| `scripts/check.sh` | **the gate** — pre-push, CI (`--ci`), and you all run it; `--fast`/`--env` tiers |
| `.githooks/` + `scripts/setup-hooks.sh` | local guardrails: `pre-commit` blocks `main`, `commit-msg` blocks AI attribution, `pre-push` runs the gate |
| `scripts/setup-governance.sh` | GitHub-side branch protection + security via `gh api` |
| `docs/CORNERSTONES.md` | the full checklist, one line per standard |
| `optional/base.css` | design-token seed from jseverino.com — opt in for frontends |

## The contract, in one breath

A tool declares its surface once in `describe_spec()`. The human `-h` text and
the machine `--describe` JSON are two pure renders of that one declaration, so
they can't disagree. Every command carries an `effect`
(`read < local_write < vault_write < remote_write < deploy`) so an agent can
risk-gate before it acts. The canonical emitter lives at
`"$TOOLS_HOME/lib/describe.sh"` — this starter sources it, never copies it.

Full standard: [`jseverino.com/schemas/cordon-v4.json`](https://jseverino.com/schemas/cordon-v4.json)
and the [`cordon`](https://github.com/joeseverino/cordon) spec repo.

## License

[MIT](LICENSE) © Joe Severino
