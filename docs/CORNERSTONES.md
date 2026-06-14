# Cornerstones

The standing standards every Severino repo carries. One line each; the why lives
in the vault. This is the checklist `cordon-starter` exists to satisfy.

## Command surface

- [ ] Every CLI surface renders from one `describe_spec()` — no hand-written help.
- [ ] `<tool> --describe` emits a valid Cordon v4 contract; `-h` renders from the
      same spec. They cannot drift.
- [ ] Every tool/command declares an honest `effect`
      (`read < local_write < vault_write < remote_write < deploy`), plus
      `+network` / `+interactive` when true.
- [ ] The `describe.sh` emitter is **sourced** from `"$TOOLS_HOME/lib/describe.sh"`,
      not copied into the repo.
- [ ] The committed `contract/*.json` golden matches the live `--describe`
      (drift checked by `scripts/check.sh`).

## Git workflow

- [ ] Never commit to `main`. Branch from a freshly fetched `origin/main`:
      `git fetch origin && git checkout -b <feature> origin/main`.
- [ ] One feature = one branch name, if multipe feuatures are arising, increasing the branch scope is justified and renaming, reused across repos when it spans them.
- [ ] Solo-authored: no `Co-Authored-By`, no AI attribution in commits or PRs.
- [ ] Hand back only on green CI with zero unresolved PR comments.
- [ ] Local hooks make it stick even offline: `scripts/setup-hooks.sh` sets
      `core.hooksPath=.githooks` — `pre-commit` blocks `main`, `pre-push` runs
      `scripts/check.sh`. Bypass: `ALLOW_MAIN_COMMIT=1` / `git push --no-verify`.

## GitHub governance (`scripts/setup-governance.sh`)

- [ ] `main` protected: required status check `ci` (strict), conversations
      resolved before merge.
- [ ] `enforce_admins: false` — admin bypass allowed; you review and merge.
- [ ] Force-push and branch deletion disabled.
- [ ] Vulnerability alerts + automated security fixes on.

## CI (`.github/workflows/ci.yml`)

- [ ] shellcheck on `bin/` + `scripts/` (`-x`, sourced files use directives).
- [ ] Cordon schema conformance on every committed contract.
- [ ] Add language lint/scanners to match the repo's narrative:
      - Security-focused (plugin, scanner, detection engine) → visible scanner
        (Semgrep for PHP/WordPress, CodeQL where supported) **and** a badge.
      - Plain CLI / library → lint-only, optional badge.
      - "No CI is the pitch" repos → skip the badge deliberately.
- [ ] Syntax-check matrix across every version the README claims to support.
- [ ] Run the exact CI command locally before pushing (`scripts/check.sh`);
      a dev-mode pass is not a CI pass.

## Files

- [ ] `AGENTS.md` (+ `CLAUDE.md` symlink), `LICENSE` (MIT, Joe Severino),
      `README.md` with the `ci` badge, `SECURITY.md`, `CHANGELOG.md`
      (two-axis: starter SemVer + Cordon `schema_version`).
- [ ] Paths read from `~/.zshrc` vars (`$CODE_HOME`, `$TOOLS_HOME`, …) — never
      hardcode `$HOME/Documents/...`.
