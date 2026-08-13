# V1 Scope

V1 is the local, single-user macOS product described by schema version 2 and versioned as `1.0.0-rc.1` during acceptance.

## Included

- Scene creation, editing, validation, duplication, deletion, reviewed import/export, and V1 migration
- Eleven typed action families, activation/deactivation lists, DAG dependencies, bounded concurrency, conditions, failure/retry/idempotency/output policies, health checks, cancellation, and recovery records
- Local app/URL/file/process/window effects; VS Code-family, Terminal/iTerm, Docker Compose, and Shortcuts integrations
- Exact process approvals, Keychain secret references, redaction, local durable history, and atomic persistence
- Menu bar, dashboard, builder, current run, history, capture, integrations, permissions, settings, diagnostics, command palette, activation overlay, onboarding, and About surfaces
- Optional global hotkey, double-clap, on-device voice, spoken status, notifications, and launch at login
- Universal release packaging, security audit, CI, checksum, dependency inventory, signing/notarization hooks, and release documentation

## Excluded

- AI generation, accounts, hosted services, cloud sync, team sharing/policies, remote execution, payments, telemetry, and advertising
- Arbitrary plug-ins, shell command strings, AppleScript/browser automation, administrator privileges, Full Disk Access, camera, screen recording, and input monitoring
- Automatic update delivery in RC1; the documented strategy is manual, consentful GitHub Releases until an independently reviewed updater exists
- Automatic capture, save, activation, or permission granting

## Release gates outside automation

Human macOS visual/interaction/VoiceOver testing, real permission flows, real installed-tool workflows, noisy-room audio validation, Developer ID credentials, notarization, and clean-machine Gatekeeper installation remain mandatory before a stable `1.0.0` release.
