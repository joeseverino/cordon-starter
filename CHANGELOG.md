# Changelog

Two axes, kept distinct:

- **Starter release** — this repo, on [SemVer](https://semver.org). Bump when the
  scaffold's own shape changes.
- **Cordon `schema_version`** — the contract revision the emitted JSON targets
  (currently `4`, schema `cordon-v4.json`). Tracked separately because a project
  can stay on the starter while the contract revs.

## [Unreleased]

### Changed
- **Checks engine model documented.** The `run_checks` gate step now runs
  cordon's full checks *engine*: built-in invariants plus this repo's own
  `commands[]` specs (a test suite, a type check, a bespoke audit — declared as
  data in `cordon.checks.json`, spec code stays home), folded into one verdict.
  Each check is capability-gated (`requires` git/macos/built-dir/`<binary>`, with
  `!` negation), so the scaffold is lean by default and skips fail-soft what the
  environment can't satisfy. `cordon.checks.json` ships an explicit `commands: []`
  (schema-autocompleted) alongside the off-by-default `idempotence`. See AGENTS.md
  → "Repo checks config" and CORNERSTONES.md → CI.

### Added
- Initial scaffold: Cordon emit-once example tool, CI conformance gate,
  `scripts/check.sh` pre-push gate, `scripts/setup-governance.sh` branch
  protection + security, AGENTS.md cornerstone playbook, optional design tokens.

  Targets Cordon `schema_version: 4`.
