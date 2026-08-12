# Adding a Built-in Integration

V1 integrations are compiled, reviewed adapters. Workspace Orchestrator does not load third-party code dynamically.

1. Add or extend a strongly typed payload in SceneCore. Never add a free-form script or command string.
2. Validate every path, identifier, bound, control character, retry policy, permission, and destructive option in `SceneValidator`.
3. Generate an absolute executable and ordered argument array in WorkspaceIntegrations. Do not invoke a shell, depend only on `PATH`, or accept raw argument fragments that bypass the typed model.
4. Keep operating-system work behind a `Sendable` protocol. The orchestration engine must remain platform-neutral.
5. Make discovery report the actual installed/missing state, version/path when available, permission, and a plain-language privacy note.
6. Add exact command-builder tests, missing-tool tests, failure tests, redaction tests, and any security regression tests. Automated tests must not launch real applications, browsers, Docker projects, Shortcuts, or public network calls.
7. Document execution, stop/ownership behavior, idempotency, permissions, privacy, and residual limitations.

Integrations that execute a binary participate in process approval. Material configuration changes invalidate the saved fingerprint. Destructive behavior requires a separate explicit confirmation and must not retry by default.
