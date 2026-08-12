# V1 Release Candidate Execution Plan

This document is the recoverable working plan for the `1.0.0-rc.1` effort. A checked item means the repository implementation and applicable automated verification are complete; it does not imply human visual approval, Developer ID signing, or notarization.

## Baseline (2026-08-12)

- Repository: `https://github.com/ahmadmemon/workspace-orchestrator`
- Starting revision: `5f0e043` on clean `main`; `main...origin/main` was `0 0` after `git fetch --prune origin`.
- `swift build --target SceneCore`: passed in 0.91 seconds after allowing SwiftPM access to its user cache. The first sandboxed attempt failed because `/Users/ahmad/.cache/clang/ModuleCache` was not writable; this was an execution-environment restriction, not a repository failure.
- `swift build`: passed in 0.08 seconds.
- `swift test`: 28 tests passed, 0 failures, 0 skipped.
- Debug Xcode build: `** BUILD SUCCEEDED **` using the command below.
- Open GitHub issues inspected: #1 Reliable Orchestration, #2 Workspace Restoration, #3 Activation Experience, #4 Open-Source Release Quality, and #5 Commercial / Team Layer. Issue #5 remains post-V1.

## Phase 1 — Plan and architecture

- [x] Inspect repository, documentation, ADRs, sources, tests, workflows, project settings, and open milestone issues.
- [x] Fetch and confirm clean/current `main`.
- [x] Record an exact baseline and create `feat/v1-release-candidate`.
- [ ] Add ADRs for schema V2, orchestration scheduling, storage/history, permissions, and release strategy.
- [ ] Update architecture and contributor boundaries.

Acceptance: changes preserve the local-first native architecture; SceneCore remains Foundation-only; every side effect is protocol-backed; no hosted/team scope is added.

## Phase 2 — SceneCore V2 and data safety

- [ ] Add backward-compatible schema V2 with stable IDs, metadata, activation/deactivation actions, dependencies, failure/retry/idempotency policies, conditions, checks, and typed action payloads.
- [ ] Migrate V1 scenes with an original-data backup and explicit errors.
- [ ] Add validation for every action, DAG references/cycles, bounds, restricted executables, URLs, paths, control characters, and destructive Docker options.
- [ ] Add trust, process-approval fingerprints, Keychain references, redaction, versioned import/export, and durable bounded run history.
- [ ] Update examples and schema documentation.

Acceptance: existing V1 data loads without loss; corrupt/invalid data is preserved; imports are untrusted and never execute automatically; secret values never serialize into scenes.

## Phase 3 — Reliable orchestration

- [ ] Add a platform-neutral OrchestrationEngine with deterministic DAG scheduling and bounded parallelism.
- [ ] Implement state derivation, dependency waits/skips, typed failure policies, bounded retry/backoff/jitter with an injectable clock, cancellation, timeouts, and deactivation planning.
- [ ] Add typed HTTP, TCP, process, application, file, and Docker health checks behind mockable adapters.
- [ ] Add resource ownership, idempotency, cleanup, interruption persistence, and safe recovery choices.
- [ ] Add managed processes with bounded output, graceful stop, and documented child-process limitations.

Acceptance: Ready is derived only after required work/checks succeed; retries and waits are bounded/visible; required failures do not silently continue; cancellation propagates; repeated runs avoid uncontrolled duplicates.

## Phase 4 — Native integrations and workspace restoration

- [ ] Add typed adapters for applications, browsers/URLs, files/folders/bookmarks, VS Code family, terminals/tmux, Docker Compose, and macOS Shortcuts.
- [ ] Add real integration discovery and diagnostics.
- [ ] Add Accessibility-gated window capture/restoration, normalized frames, multi-display mapping/fallback, matching, preview, and tests.
- [ ] Add reviewed Capture Current Workspace flow that excludes sensitive apps and never captures prohibited data.

Acceptance: commands always use an executable plus structured arguments; missing tools and permissions degrade honestly; only owned resources are stopped by default; captured scenes require review and are not run.

## Phase 5 — Activation and platform services

- [ ] Add configurable Carbon global hotkey without key logging.
- [ ] Add opt-in local double-clap signal processing with calibration, cooldown, noise adaptation, and deterministic fixtures.
- [ ] Add explicit on-device Speech mode and deterministic voice command parsing with confirmation for fuzzy/ambiguous matches.
- [ ] Add optional spoken status, notifications, `SMAppService` launch-at-login, permission status/settings links, and a truthful activation overlay.

Acceptance: activation services are disabled by default, permission-scoped, locally processed, visibly active, cancellable, and never silently fall back to cloud speech or run an ambiguous scene.

## Phase 6 — Obsidian Command Center experience

- [ ] Centralize semantic color, spacing, radius, typography, shadow, and motion tokens.
- [ ] Add the original accessible Workspace Core and compact variant.
- [ ] Implement onboarding, dashboard, scene library/builder, current run/details, run history, capture, integrations, permissions, settings, diagnostics, about, command palette, overlay, and compact menu-bar controls.
- [ ] Support keyboard navigation, VoiceOver, status text, identifiers, Reduce Motion, Reduce Transparency, and increased contrast.
- [ ] Add original generated app icon source and complete asset set.

Acceptance: all states and progress reflect actual models; no fake telemetry; optional/required failures are distinct; the application remains usable without optional permissions.

## Phase 7 — Quality, documentation, and release engineering

- [ ] Expand unit, integration, security, performance, and deterministic UI-test coverage.
- [ ] Add safe manual smoke-test mode/checklist and accessibility checklist.
- [ ] Complete user, privacy, threat-model, integration, import/export, troubleshooting, design, scope, and release documentation.
- [ ] Set `1.0.0-rc.1`, add archive/package/checksum/SBOM scripts, hardened-runtime/usage descriptions/limited entitlements, and credential-gated signing/notarization automation.
- [ ] Expand PR/main and release CI; add prohibited-pattern and documentation checks.

Acceptance: package tests, Debug and Release app builds, UI tests, security scan, packaging, and unsigned artifact verification pass; signing/notarization status is reported exactly.

## Phase 8 — Audit and publication

- [ ] Review full diff/status, warnings, test counts, artifact contents, and every security-audit match.
- [ ] Update `PROJECT_STATUS.md`, roadmap, CHANGELOG, issue checklists, and this plan truthfully.
- [ ] Create logical commits, push the branch, open the requested PR, inspect CI, fix failures, and leave the PR unmerged for review.
- [ ] Provide the exact human visual, permission, integration, audio, and credential verification checklist.

Acceptance: working tree is clean; CI is passing or exact external blockers are documented; no stable V1 release/tag is created before human acceptance.

## Deviations and blockers

- None at plan creation.
- Expected external gates: human visual/interaction acceptance and Developer ID/notarization credentials. These do not excuse incomplete core implementation.

## Verification commands

```bash
swift build --target SceneCore
swift build
swift test
xcodebuild -project WorkspaceOrchestrator.xcodeproj -scheme WorkspaceOrchestratorApp -configuration Debug -destination 'platform=macOS' -derivedDataPath .build/XcodeDerivedData CODE_SIGNING_ALLOWED=NO build
xcodebuild -project WorkspaceOrchestrator.xcodeproj -scheme WorkspaceOrchestratorApp -configuration Release -destination 'platform=macOS' -derivedDataPath .build/XcodeDerivedData CODE_SIGNING_ALLOWED=NO build
```

Additional UI-test, archive, packaging, and security-scan commands will be recorded here after their scripts/targets are implemented and verified.
