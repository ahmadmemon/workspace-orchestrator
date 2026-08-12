# Project Status

- **Project name:** Workspace Orchestrator
- **Current milestone:** V1 Release Candidate — final local completion and publication pass in progress
- **Current branch:** `feat/v1-release-candidate`
- **Overall project completion estimate:** 95%
- **Release candidate version:** `1.0.0-rc.1` (build `1`)
- **Product status:** Unsigned, unnotarized V1 release candidate
- **GitHub repository:** https://github.com/ahmadmemon/workspace-orchestrator
- **Publication status:** Branch push, pull request creation, and hosted CI verification are blocked by an invalid local GitHub CLI token.
- **Post-V1 boundary:** Hosted collaboration, commercial/team features, and a cloud backend remain explicitly out of scope.

## Completed work

- Evolved the local scene format to schema V2 with atomic V1 migration, source backups, strict validation, trust state, typed actions, activation/deactivation plans, and backwards-conscious decoding.
- Added deterministic dependency scheduling, bounded parallelism, retries, conditions, failure policies, typed health checks, cancellation, deactivation, managed-resource ownership, bounded history, and interrupted-run recovery.
- Completed snapshot-backed Run History with scene/status/local-calendar date filtering, full action details, safe full or failed-and-dependent retry previews, current validation/approval/secret checks, scene-copy recovery, bounded redacted diagnostic export, storage reporting, selective deletion, configurable retention primitives, and corruption-preserving pruning.
- Added protocol-backed local integrations for applications, URLs/browsers, files/folders, structured executables, VS Code-family editors, terminals, tmux, Docker Compose, Shortcuts, and window layouts.
- Added reviewed workspace capture, normalized multi-display restoration, missing-display fallback, honest integration discovery, process approvals, Keychain references, redaction, and reviewed scene import/export.
- Added local activation by global shortcut, opt-in double clap, and explicit on-device voice command sessions, plus spoken status, notifications, launch at login, an overlay, and transparent permission controls.
- Completed the native Obsidian Command Center foundation: onboarding, menu bar, Workspace Core, dashboard, scene library/builder, current-run details, searchable/status-filtered history, capture, integrations, permissions, settings tabs, diagnostics, command palette, import review, approval flows, and an original icon.
- Added release-candidate CI/release workflows, security and version gates, universal packaging, checksums, dependency inventory, SPDX SBOM, source provenance, and comprehensive user/developer/release documentation.
- Expanded automated coverage from the 28-test baseline to 92 Swift package tests plus 4 deterministic XCUITests. All 96 tests pass locally with no skipped or flaky tests observed.

## Remaining release gates

- Complete the remaining requested Settings behavior: default scene/menu-bar choices, animation/compact/sound controls, clap action and confirmation policy, editable execution defaults, and privacy/Keychain management controls.
- Complete the requested double-clap calibration/test flow and automatic pause behavior for unreliable or unavailable microphone conditions.
- Ahmad must perform the documented visual, keyboard, VoiceOver, permission, real-integration, multi-display, audio, and clean-machine acceptance checklist.
- GitHub CLI authentication must be repaired before the branch can be pushed, the required unmerged pull request opened, milestone issue checklists updated, and hosted CI inspected.
- Developer ID credentials and an Apple notarization profile are required to sign, notarize, staple, and publish a distributable release candidate.
- Maintainer review and acceptance are required before merge; a stable `v1.0.0` tag or public stable release is not authorized yet.

## Known limitations

- The unsigned local package will trigger normal macOS trust warnings and is not suitable for public stable distribution.
- The scene editor represents process arguments one per line, so it cannot author an argument containing a literal newline even though the model supports one.
- Imported or integration-authored conditions and health checks are preserved and visible, but their advanced structured fields are not all directly editable in the V1 builder.
- Real Accessibility behavior, permission prompts, hardware audio classification, live third-party tools, and multi-display matching cannot be fully covered by deterministic automated tests.
- Xcode 15.4 reports non-fatal missing log-store-manifest and UI-result attachment-staging warnings in this local environment; builds and tests exit successfully and result metrics contain no test issues.

## Verification record — 2026-08-12

- `scripts/security-audit.sh`: passed (`Security and documentation audit passed.`)
- `scripts/verify-version.sh`: passed (`Version verified: 1.0.0-rc.1 (1)`)
- `swift build --target SceneCore`: passed
- `swift build`: passed
- `swift test`: 97 tests executed, 0 failures, 0 unexpected failures
- `xcodebuild -quiet -project WorkspaceOrchestrator.xcodeproj -scheme WorkspaceOrchestratorApp -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/XcodeDerivedData-UITests test`: 4 tests, 0 result issues
- Unsigned arm64 Debug app build: passed
- Unsigned universal Release app build: passed
- Release executable architectures: `x86_64 arm64`
- Built bundle version: `1.0.0-rc.1` (`1`)
- Universal archive/package workflow: previously passed; a final clean-source unsigned package is produced after this status commit.

## Baseline comparison

Work began from clean revision `5f0e043`, where `main...origin/main` was `0 0`, 28 tests passed, and the unsigned arm64 Debug app built successfully. The V1 release-candidate branch preserves that baseline while adding the capabilities and verification recorded above.
