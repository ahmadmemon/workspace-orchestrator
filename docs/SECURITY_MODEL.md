# Security Model

## Trust boundaries

Scene files, imports, executable paths and arguments, URLs, environment references, process output, filesystem metadata, tool output, window titles, and activation audio/transcripts are untrusted. The application validates at decode/save/execute boundaries and does not treat local origin as proof of safety. Unknown schema versions and action types fail closed.

## Process controls

A process request contains an absolute executable URL, structured argument array, optional absolute working directory, typed environment values, and timeout. Shell command strings, interpreter `-c` wrappers, `sudo`, `/usr/bin/env` indirection, control characters, relative executable paths, and destructive Docker options are rejected. Processes run as the current user and never elevate privileges.

Process approval is exact: the fingerprint includes executable, arguments, working directory, and environment names/value kinds. Users may approve once or remember that exact fingerprint. One-time approvals are consumed. Editing any bound field requires new approval. Imported scenes never inherit trust merely because a similar scene exists.

## Secrets and output

Secrets are stored through the macOS Keychain adapter; scene JSON contains only a stable secret reference. Logs and history apply field-pattern redaction and bounded output/retention policies. The UI warns that paths, arguments, stdout, stderr, window titles, and diagnostics can still contain private data. Nothing is uploaded automatically.

## Network and integrations

Only explicit HTTP(S) URL actions and health checks contact a network. HTTP health uses the system TLS trust policy; certificate validation is never disabled. TCP checks are bounded and connect only to the configured host/port. VS Code, terminal, Docker, and Shortcuts integrations resolve known executable locations and build inspectable argument arrays. Missing tools fail visibly.

## Files, imports, and persistence

Scene, approval, live-run, and history storage uses application-specific directories and atomic writes. Corrupt source data is preserved and surfaced. Imports are decoded into a review model, identify duplicates and risky actions, remain untrusted, and never auto-run. File actions use explicit paths; the schema supports bookmark references for portable access without requesting Full Disk Access.

## Window and activation permissions

Accessibility gates window enumeration and placement only. Microphone and Speech gate their respective opt-in services. The global shortcut uses a registered Carbon event, not key logging. Clap detection reduces audio to transient features and does not persist recordings. Voice uses Apple's on-device recognition setting and rejects ambiguous scene matches without confirmation. Services expose an active indicator and stop when disabled.

## Distribution controls

The app uses hardened runtime and only the audio-input entitlement required by microphone activation. Direct distribution is planned through a universal Developer ID archive, notarization, checksum, dependency inventory, source revision, and toolchain record. Credentials are supplied by the release environment and never stored in the repository. Unsigned artifacts are development/verification outputs, not a public stable release.

## Explicitly prohibited

- Shell wrappers or arbitrary command strings
- Privilege elevation or administrator prompts
- Disabling TLS verification or Gatekeeper
- Embedded secrets, signing certificates, or tokens
- Telemetry, cloud execution, accounts, or remote control
- Silent permission requests, captured-scene execution, or ambiguous voice activation
- Accessibility, microphone, or Speech use outside the feature the user enabled

See [Threat model](THREAT_MODEL.md), [Privacy](PRIVACY.md), [Permissions](PERMISSIONS.md), and [Security policy](../SECURITY.md).
