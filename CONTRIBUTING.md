# Contributing

Thank you for helping build Workspace Orchestrator. Begin by reading `AGENTS.md`, `PROJECT_STATUS.md`, and the active milestone in `docs/ROADMAP.md`.

Discuss substantial features before implementation. Keep pull requests focused, preserve the component boundaries, and do not introduce post-V1 hosted/team functionality through an unrelated change.

## Development checklist

1. Create a focused branch.
2. Add or update deterministic tests without launching real applications or browsers.
3. Run `scripts/security-audit.sh`, `swift build`, and `swift test`.
4. Run the Debug and Release app builds documented in `docs/RELEASE.md`.
5. Update relevant documentation, `CHANGELOG.md`, and `PROJECT_STATUS.md`.
6. Review the diff/status for secrets, personal paths, generated release output, schema compatibility, unsafe process behavior, and unmocked side effects.
7. For release-affecting changes, run the non-overwriting package script and complete applicable `docs/SMOKE_TEST.md` items.

Contributions are accepted under Apache License 2.0. Participation must follow the Code of Conduct. Security issues must be reported privately according to `SECURITY.md`, not through a public issue.
