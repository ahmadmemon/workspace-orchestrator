# Workspace Orchestrator

Workspace Orchestrator is a local-first native macOS application that restores saved workspaces as explicit, observable scenes. The V1 release candidate combines structured orchestration, developer-tool integrations, reviewed window capture, and opt-in local activation without accounts, telemetry, or cloud execution.

> Status: `1.0.0-rc.1` is under automated verification. Developer ID signing, notarization, and human visual/permission testing remain external release gates.

## V1 capabilities

- Native SwiftUI menu-bar app and Obsidian Command Center dashboard for macOS 14+
- Scene schema V2 with V1 migration, validation, import/export review, and local atomic persistence
- Deterministic dependency graph, bounded parallelism, conditions, retries, health checks, failure policies, cancellation, deactivation, and durable run history
- Eleven typed actions: applications, URLs, files/folders, one-shot and managed processes, waits, VS Code-family workspaces, terminal workspaces, Docker Compose, macOS Shortcuts, and window layouts
- Explicit process approval bound to executable, arguments, working directory, and environment references
- Optional global shortcut, local double-clap, on-device voice commands, spoken status, notifications, and launch-at-login services
- Accessibility-gated reviewed window capture and restoration
- No shell command strings, privilege escalation, accounts, analytics, cloud dependency, or embedded secrets

See the [V1 scope](docs/V1_SCOPE.md), [quick start](docs/QUICK_START.md), and [user guide](docs/USER_GUIDE.md).

## Architecture

The Swift packages enforce one-way dependencies:

```text
WorkspaceOrchestratorApp
  ├── ActivationKit ───────────────> SceneCore
  ├── WorkspaceIntegrations ───────> MacAutomation ──> OrchestrationEngine ──> SceneCore
  └───────────────────────────────────────────────────────────────────────> SceneCore
```

`SceneCore` owns portable schemas, validation, persistence, history, and security models. `OrchestrationEngine` owns deterministic scheduling. `MacAutomation` owns macOS side effects behind protocols. `WorkspaceIntegrations` builds typed integration requests. `ActivationKit` owns opt-in local activation. SwiftUI views coordinate these modules but never execute processes directly.

Read [Architecture](docs/ARCHITECTURE.md), [Security model](docs/SECURITY_MODEL.md), and [Threat model](docs/THREAT_MODEL.md).

## Requirements

- macOS 14 or newer
- Xcode 15.4 or newer with a Swift 5.10-compatible toolchain
- No third-party runtime dependencies

## Build and test

```bash
swift build --target SceneCore
swift build
swift test
xcodebuild -project WorkspaceOrchestrator.xcodeproj -scheme WorkspaceOrchestratorApp -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/XcodeDerivedData CODE_SIGNING_ALLOWED=NO build
```

Release verification and packaging:

```bash
scripts/security-audit.sh
scripts/verify-version.sh
scripts/build-release.sh
```

The release script refuses to overwrite an existing output directory, tests first, archives a universal `arm64`/`x86_64` app, and emits a ZIP, checksum, dependency inventory, source revision, and toolchain record. Signing and notarization run only when the documented credentials are configured.

## Local development

Open `WorkspaceOrchestrator.xcodeproj`, select `WorkspaceOrchestratorApp` and **My Mac**, then Run. The application appears in the menu bar; choose **Open Dashboard**. Install the demo scene explicitly, review it, approve any process action when prompted, and activate only when ready.

Scene and run data live under `~/Library/Application Support/WorkspaceOrchestrator`. Secrets belong in Keychain and scenes contain references only. Imported scenes always enter an untrusted review flow and never run automatically.

## Safety

Process actions execute local programs as the current user. Workspace Orchestrator accepts only an executable plus a structured argument array; it rejects shell wrappers, `sudo`, control characters, unsupported URLs, invalid dependency graphs, and unsafe imported execution until reviewed. See [Permissions](docs/PERMISSIONS.md), [Privacy](docs/PRIVACY.md), and [Import/export](docs/IMPORT_EXPORT.md).

## Contributing and support

Read [CONTRIBUTING.md](CONTRIBUTING.md), [SECURITY.md](SECURITY.md), the [roadmap](docs/ROADMAP.md), and [troubleshooting](docs/TROUBLESHOOTING.md). Licensed under [Apache-2.0](LICENSE). Copyright 2026 Ahmad Memon.
