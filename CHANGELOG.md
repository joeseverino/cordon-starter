# Changelog

Two axes, kept distinct:

- **Starter release** — this repo, on [SemVer](https://semver.org). Bump when the
  scaffold's own shape changes.
- **Cordon `schema_version`** — the contract revision the emitted JSON targets
  (currently `4`, schema `cordon-v4.json`). Tracked separately because a project
  can stay on the starter while the contract revs.

## [Unreleased]

### Added
- Initial scaffold: Cordon emit-once example tool, CI conformance gate,
  `scripts/check.sh` pre-push gate, `scripts/setup-governance.sh` branch
  protection + security, AGENTS.md cornerstone playbook, optional design tokens.

  Targets Cordon `schema_version: 4`.
