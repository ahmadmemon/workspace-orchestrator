# Scene Schema

Workspace Orchestrator scene files are versioned JSON and are always treated as untrusted input.

## Versions

- Version 1: one sequential `actions` list with application, URL, and structured process actions.
- Version 2: activation and deactivation plans; bounded concurrency; tags, favorite/icon and trust metadata; dependencies; retry, failure, idempotency and output policies; conditions and health checks; and the closed V1 action families.

V1 files migrate locally to V2. Before replacement, the exact original `scenes.json` bytes are copied under `migration-backups`. V1 concurrency becomes `1`, preserving action order. Unsupported versions and unknown action kinds fail closed.

## Security invariants

- Process definitions use an absolute executable and an argument array, never a shell command string.
- Generic shells, `osascript`, `sudo`, and `/usr/bin/env` are restricted for generic process actions.
- Sensitive environment entries contain only a stable Keychain reference.
- Imports start as `importedUntrusted`, never run automatically, and expose a review inventory of apps, URLs, paths, binaries, destructive operations, and permissions.
- Material executable, argument, environment-name, timeout, retry, managed-process, or stop-policy changes produce a different SHA-256 approval fingerprint.

The canonical Codable definitions live in `Packages/SceneCore/Sources/SceneCore`.
