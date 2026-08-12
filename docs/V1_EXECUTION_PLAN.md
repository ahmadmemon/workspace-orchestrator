# V1 Release Candidate Execution Plan

This is the recoverable plan for `1.0.0-rc.1` on `feat/v1-release-candidate`. A checked item means repository implementation and applicable automated verification are complete; it never implies human visual approval, Developer ID signing, or notarization.

## Baseline — 2026-08-12

- Starting revision `5f0e043`; clean/current `main...origin/main` was `0 0` after fetch.
- `swift build --target SceneCore` and `swift build` passed.
- `swift test` passed 28 tests with 0 failures.
- Unsigned arm64 Debug Xcode build passed.
- GitHub issues #1–#5 were inspected; #5 hosted/team work remains post-V1.

## 1. Architecture and schema

- [x] Establish the RC plan, branch, V1 boundary, schema/orchestration/activation/persistence-release ADRs, and module boundaries.
- [x] Implement V2 metadata, activation/deactivation plans, eleven typed actions, dependencies, conditions, policies, and checks.
- [x] Migrate V1 atomically with source backup; preserve corrupt input and fail closed on unknown versions/actions.
- [x] Add strict validation, trust/import state, exact approvals, Keychain references, redaction, archives, and bounded history.

## 2. Reliable orchestration

- [x] Implement deterministic DAG scheduling with stable order and bounded parallelism.
- [x] Implement failure/dependency behavior, bounded retry/backoff/jitter, injectable clock, timeouts, cancellation, deactivation, and immutable snapshots.
- [x] Implement typed HTTP/TCP/process/application/file/Docker health checks and resource ownership records.
- [x] Implement managed-process tracking, bounded output, graceful stop, interruption persistence, and explicit recovery presentation.

## 3. Integrations and workspace restoration

- [x] Implement protocol-backed application, browser/URL, file/folder, structured process, editor, terminal, Docker Compose, and Shortcuts execution.
- [x] Implement honest local integration discovery and missing-tool errors.
- [x] Implement Accessibility-gated window capture/restoration, normalized frames, display mapping/fallback, matching, and math tests.
- [x] Implement reviewed capture of eligible running applications/windows with sensitive/self exclusions and no automatic execution.

## 4. Activation and platform services

- [x] Implement Carbon global shortcut registration without key logging.
- [x] Implement opt-in local double-clap transient detection with cooldown/noise rules and deterministic fixtures.
- [x] Implement on-device Speech configuration, deterministic voice parsing/matching, and ambiguity confirmation boundary.
- [x] Implement optional spoken status, local notifications, launch at login, permission state/settings links, and activation overlay.

## 5. Native experience

- [x] Centralize Obsidian semantic tokens and Workspace Core visual state.
- [x] Implement onboarding, dashboard/library/builder, current run/details, history, capture, integrations, permissions, settings, diagnostics, About, command palette, overlay, menu-bar controls, import review, and process approval sheets.
- [x] Add keyboard/native semantic controls, textual status, reduced-motion/transparency support, and accessibility labels for primary controls.
- [x] Generate an original icon master and complete Xcode asset set.

Human verification remains required for navigation polish, every VoiceOver/focus path, adaptive layouts, icon rendering, real permission prompts, and hardware audio behavior.

## 6. Quality, documentation, and release engineering

- [x] Expand deterministic unit/integration/security/reliability/performance coverage from the 28-test baseline to 92 passing package tests, plus 4 deterministic XCUITests.
- [x] Add user, quick-start, builder, integration, permissions, privacy, threat, troubleshooting, import/export, design, scope, smoke-test, and release documentation.
- [x] Set `1.0.0-rc.1` build 1, hardened runtime, limited entitlement, version/security gates, and non-overwriting universal packaging with checksums/inventory/provenance.
- [ ] Verify PR/main CI and credential-gated release automation after workflow changes are committed and pushed.
- [x] Execute the full local Debug/Release/universal archive/security verification matrix after final code changes.

## 7. Audit and publication

- [x] Review full diff/status, warnings, test counts, artifact contents, architecture slices, security matches, and documentation links.
- [x] Update `PROJECT_STATUS.md` and this plan with exact final local evidence.
- [ ] Push branch, open the requested unmerged PR, inspect CI, and fix repository-caused failures.
- [ ] Complete the human/credential checklist or record each external blocker without claiming success.

## Verification commands

```bash
scripts/security-audit.sh
scripts/verify-version.sh
swift build --target SceneCore
swift build
swift test
xcodebuild -project WorkspaceOrchestrator.xcodeproj -scheme WorkspaceOrchestratorApp -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/XcodeDerivedData CODE_SIGNING_ALLOWED=NO build
xcodebuild -project WorkspaceOrchestrator.xcodeproj -scheme WorkspaceOrchestratorApp -configuration Release -destination 'platform=macOS' -derivedDataPath .build/XcodeDerivedData CODE_SIGNING_ALLOWED=NO ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO build
OUTPUT_DIR=/absolute/new/output scripts/build-release.sh
```

The first incremental `swift test` after public scheduler-model changes crashed in stale SwiftPM ABI/cache state (signals 10/11). `swift package clean` followed by a full rebuild passed all tests, confirming an environment-derived cache issue rather than a reproducible source failure. The final suite passed 92 package tests and 4 XCUITests with no failures.

## External release gates

- Human visual, keyboard, VoiceOver, permission, real-integration, multi-display, audio, and clean-machine testing
- Apple Developer ID signing identity and notarization Keychain profile
- Valid GitHub CLI authentication for branch publication, pull-request creation, milestone issue updates, and hosted CI inspection
- Maintainer approval and passing hosted CI

No stable V1 tag or automatic merge is authorized before these gates pass.
