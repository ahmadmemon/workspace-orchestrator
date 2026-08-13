# Roadmap

Checked items describe repository implementation. Human visual/permission testing, Developer ID signing, and notarization are separate release gates and are never implied by a checked engineering item.

## V1 — Local Workspace Orchestration

V1 combines the formerly staged reliability, restoration, activation, and open-source release-quality milestones into the approved `1.0.0-rc.1` scope.

- [x] Schema V2, V1 migration/backup, strict validation, reviewed import/export, approvals, Keychain references, redaction, and bounded local history
- [x] Deterministic dependency orchestration with bounded parallelism, policies, retries, conditions, typed health checks, cancellation, deactivation, and interruption records
- [x] Structured macOS/application/URL/file/process actions and optional editor, terminal, Docker Compose, Shortcuts, and window integrations
- [x] Accessibility-gated reviewed window capture/restoration with normalized multi-display mapping
- [x] Opt-in global shortcut, double-clap, on-device voice parsing, spoken status, local notifications, launch at login, and activation overlay foundations
- [x] Native Obsidian Command Center surfaces, scene builder, current run/history, capture, integrations, permissions, settings, diagnostics, menu bar, command palette, onboarding, About, and app icon
- [x] Expanded deterministic package coverage, Debug/Release build configuration, documentation/security checks, and universal release packaging with credential-gated signing/notarization
- [ ] Complete human visual, keyboard, VoiceOver, permission, real-integration, multi-display, and audio smoke test on supported Macs
- [ ] Sign with Developer ID, notarize, staple, install on a clean Mac, and verify Gatekeeper
- [ ] Pass branch CI and maintainer review; publish a prerelease without auto-merging

The stable V1 boundary is documented in [V1 Scope](V1_SCOPE.md). No stable tag should be created while any release gate above remains unchecked.

## V1.x — Hardening and consentful updates

- Address verified RC findings and compatibility issues
- Improve capture/integration fidelity based on real-device evidence
- Add an independently threat-modeled, signed, opt-in update mechanism only after explicit approval
- Preserve schema compatibility and local-only use

## V2 — Optional commercial/team layer

V2 may explore encrypted synchronization, shared scenes/templates, organization policy, and collaboration only after user research and a separate identity/key-ownership threat model.

Explicit non-goals remain selling telemetry, forcing accounts for local scenes, weakening encryption, remotely executing actions without local authorization, or exposing private process output to administrators.
