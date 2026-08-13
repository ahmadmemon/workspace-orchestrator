# Changelog

All notable changes follow Keep a Changelog. The project uses Semantic Versioning; prerelease verification does not imply stable availability.

## [Unreleased]

No changes yet.

## [1.0.0-rc.1] - 2026-08-12

### Added

- Native macOS menu-bar application with Obsidian Command Center dashboard, scene library/builder, current run, history, capture, integrations, permissions, settings, diagnostics, command palette, onboarding, activation overlay, About, and original app icon.
- Scene schema V2 with V1 migration backup, activation/deactivation actions, metadata, dependencies, conditions, health checks, and execution policies.
- Eleven structured action families for applications, URLs, files, processes, waits, editor/terminal workspaces, Docker Compose, Shortcuts, and window layouts.
- Deterministic DAG scheduler with bounded parallelism, retries, failure policy, health readiness, cancellation, resource records, deactivation, and interrupted-run recovery.
- Exact process approvals, imported-scene review, Keychain references, redaction, atomic persistence, and bounded durable history.
- Optional global hotkey, local double-clap, on-device voice commands, spoken status, notifications, and launch at login foundations.
- Accessibility-gated reviewed window capture/restoration and native integration discovery.
- Universal release packaging, checksum, dependency inventory, provenance/toolchain records, security/documentation audit, and credential-gated Developer ID notarization workflow.
- Expanded deterministic test suites across SceneCore, orchestration, macOS adapters, integrations, activation, migration, security, health, and recovery.
- Snapshot-backed History with local date/status/scene filters, full action details, current-preflight retry previews, scene-copy recovery, configurable retention, and bounded redacted diagnostic export.
- Complete persisted Settings behavior, non-revealing Keychain reference management, allow-listed transfer, and typed scope-by-scope factory reset.
- Guided local double-clap calibration with explicit accept/adjust persistence, a nonexecuting diagnostic trace, exact operational pause reasons, and bounded safe recovery.
- Advanced authoring for all implemented conditions and health checks plus lossless structured arguments, including empty, whitespace-only, tab, and multiline values.

### Security

- Prohibited shell-wrapper execution, privilege elevation, TLS bypass, embedded credentials, inherited import trust, and secret serialization.
- Bound process approvals to exact structured execution details and consumed approve-once grants.

### Known release gates

- Human visual/VoiceOver/permission/integration/audio smoke testing is pending.
- Developer ID signing and Apple notarization require maintainer credentials and are pending.
