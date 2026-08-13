# Project Status

- **Project name:** Workspace Orchestrator
- **Current milestone:** V1 Release Candidate — final local completion and publication pass in progress
- **Current branch:** `feat/v1-release-candidate`
- **Overall project completion estimate:** 98%
- **Release candidate version:** `1.0.0-rc.1` (build `1`)
- **Product status:** Unsigned, unnotarized V1 release candidate
- **GitHub repository:** https://github.com/ahmadmemon/workspace-orchestrator
- **Publication status:** Local completion is in progress; GitHub authentication, push, pull-request creation, issue updates, and hosted CI are rechecked during the publication step.
- **Post-V1 boundary:** Hosted collaboration, commercial/team features, and a cloud backend remain explicitly out of scope.

## Completed work

- Evolved the local scene format to schema V2 with atomic V1 migration, source backups, strict validation, trust state, typed actions, activation/deactivation plans, and backwards-conscious decoding.
- Added deterministic dependency scheduling, bounded parallelism, retries, conditions, failure policies, typed health checks, cancellation, deactivation, managed-resource ownership, bounded history, and interrupted-run recovery.
- Completed snapshot-backed Run History with scene/status/local-calendar date filtering, full action details, safe full or failed-and-dependent retry previews, current validation/approval/secret checks, scene-copy recovery, bounded redacted diagnostic export, storage reporting, selective deletion, configurable retention primitives, and corruption-preserving pruning.
- Completed persisted Settings behavior for startup/recovery/update checks, configurable menu content, theme/effect/animation/compact/sound controls, recorded shortcut targets and safe activation choices, complete new-scene/action execution defaults, live history retention, accurate permission state, non-revealing Keychain label/dependency/replace/rename/repair/delete management, scene/settings transfer, local-data access, allow-listed settings transfer, and typed confirmation-gated reset by explicit category.
- Completed guided double-clap calibration with bounded ambient sampling plus one representative double clap, aggregate energy/duration/spectral/timing recommendations, explicit accept/adjust persistence, and a visible nonexecuting test trace. Protocol-backed audio input now reports exact permission/device/route/interruption/format/noise/clipping/sleep/manual pause reasons, attempts bounded recovery where safe without creating new engines, and preserves enabled preference separately from operational state.
- Completed advanced Scene Builder authoring for all implemented conditions and health checks, including all/any and per-condition enablement, required/optional readiness, bounded check policies, exact structured argument-array editing, safe JSON previews, strict reference validation, and lossless archive/history/migration-compatible Codable round trips.
- Added protocol-backed local integrations for applications, URLs/browsers, files/folders, structured executables, VS Code-family editors, terminals, tmux, Docker Compose, Shortcuts, and window layouts.
- Added reviewed workspace capture, normalized multi-display restoration, missing-display fallback, honest integration discovery, process approvals, Keychain references, redaction, and reviewed scene import/export.
- Added local activation by global shortcut, opt-in double clap, and explicit on-device voice command sessions, plus spoken status, notifications, launch at login, an overlay, and transparent permission controls.
- Completed the native Obsidian Command Center foundation: onboarding, menu bar, Workspace Core, dashboard, scene library/builder, current-run details, searchable/status-filtered history, capture, integrations, permissions, settings tabs, diagnostics, command palette, import review, approval flows, and an original icon.
- Added release-candidate CI/release workflows, security and version gates, universal packaging, checksums, dependency inventory, SPDX SBOM, source provenance, and comprehensive user/developer/release documentation.
- Expanded automated coverage from the 28-test baseline to 133 Swift package tests plus 9 deterministic XCUITests. The latest verification record below is authoritative.

## Remaining release gates

- Ahmad must perform the documented visual, keyboard, VoiceOver, permission, real-integration, multi-display, audio, and clean-machine acceptance checklist.
- GitHub authentication must be valid before the branch can be pushed, the required unmerged pull request opened, milestone issue checklists updated, and hosted CI inspected.
- Developer ID credentials and an Apple notarization profile are required to sign, notarize, staple, and publish a distributable release candidate.
- Maintainer review and acceptance are required before merge; a stable `v1.0.0` tag or public stable release is not authorized yet.

## Known limitations

- The unsigned local package will trigger normal macOS trust warnings and is not suitable for public stable distribution.
- Real Accessibility behavior, permission prompts, hardware audio classification, live third-party tools, and multi-display matching cannot be fully covered by deterministic automated tests.
- Xcode 15.4 reports non-fatal missing log-store-manifest and UI-result attachment-staging warnings in this local environment; builds and tests exit successfully and result metrics contain no test issues.

## Verification record — 2026-08-12

- `scripts/security-audit.sh`: passed (`Security and documentation audit passed.`)
- `scripts/verify-version.sh`: passed (`Version verified: 1.0.0-rc.1 (1)`)
- `swift build --target SceneCore`: passed
- `swift build`: passed
- `swift test`: 133 tests executed, 0 failures, 0 unexpected failures
- UI acceptance: 7 tests previously executed with 0 failures; 9-case source now compiles, with final execution pending an unlocked interactive Mac (a locked session renders the windows but prevents XCTest accessibility attachment)
- Unsigned arm64 Debug app build: passed
- Unsigned universal Release app build: passed
- Release executable architectures: `x86_64 arm64`
- Built bundle version: `1.0.0-rc.1` (`1`)
- Universal archive/package workflow: previously passed; a final clean-source unsigned package is produced after this status commit.

## Baseline comparison

Work began from clean revision `5f0e043`, where `main...origin/main` was `0 0`, 28 tests passed, and the unsigned arm64 Debug app built successfully. The V1 release-candidate branch preserves that baseline while adding the capabilities and verification recorded above.
