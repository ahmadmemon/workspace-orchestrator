# Workspace Orchestrator

A local-first native macOS application that runs reusable workspace scenes as explicit, observable sequences of safe structured actions.

> Project status: Milestone 1 — Foundation + First Working Scene is locally complete and awaiting manual UI inspection. The name and bundle identifier are provisional.

## Vision

Workspace Orchestrator aims to make returning to a complex project feel like opening one document: activate a scene and have the workspace restored, checked, and clearly reported. The first milestone deliberately establishes the reliable local foundation before adding restoration or ambient activation features.

## Current capabilities

- Native SwiftUI menu-bar application and dashboard for macOS 14+
- Create, edit, reorder, validate, save, run, and delete scenes
- Exactly three action types: open an application by bundle identifier, open an HTTP(S) URL, and run an executable with a structured argument array
- Sequential execution with stop-on-failure and cancellation
- Per-action and overall status, timing, errors, stdout, and stderr
- Atomic local JSON persistence in `~/Library/Application Support/WorkspaceOrchestrator/scenes.json`
- Explicit **Install Demo Scene** option; it is neither installed nor run automatically

Milestone 1 does **not** support window restoration, Docker, VS Code or terminal integration, health checks, parallel actions, dependencies, retries, browser automation, AppleScript, accessibility control, microphones, clap or voice activation, AI, accounts, cloud sync, telemetry, updates, signing, notarization, or App Store distribution.

## Architecture

- `SceneCore` is pure Swift domain logic: Codable scene/action schemas, validation, run models, and JSON persistence.
- `MacAutomation` owns side effects behind `ApplicationOpening`, `URLOpening`, and `ProcessRunning` protocols, plus sequential scene execution.
- `WorkspaceOrchestratorApp` is the SwiftUI presentation and application-state layer. It injects real native adapters and does not contain orchestration logic.

See [Architecture](docs/ARCHITECTURE.md) and [Security model](docs/SECURITY_MODEL.md).

## Repository structure

```text
App/WorkspaceOrchestratorApp/     SwiftUI app, menu bar, dashboard, editor
Packages/SceneCore/               Domain, validation, run models, persistence
Packages/MacAutomation/           Native adapters and SceneExecutor
Tests/                            XCTest suites using mocks where side effects exist
Examples/                         Inspectable scene examples
docs/decisions/                   Architecture decision records
.github/                          CI and contribution templates
WorkspaceOrchestrator.xcodeproj/  Native macOS application target
```

## Requirements

- macOS 14 or newer
- Xcode 15.4 or newer
- Swift 5.10-compatible toolchain
- No third-party dependencies

## Development setup

```bash
git clone <repository-url>
cd workspace-orchestrator
swift build --target SceneCore
swift test
xcodebuild -project WorkspaceOrchestrator.xcodeproj -scheme WorkspaceOrchestratorApp -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/XcodeDerivedData CODE_SIGNING_ALLOWED=NO build
```

The exact commands successfully observed for Milestone 1 were:

```bash
swift build --target SceneCore
swift test
xcodebuild -project WorkspaceOrchestrator.xcodeproj -scheme WorkspaceOrchestratorApp -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/XcodeDerivedData CODE_SIGNING_ALLOWED=NO build
```

## Launching locally

Open `WorkspaceOrchestrator.xcodeproj`, select the `WorkspaceOrchestratorApp` scheme and **My Mac**, then choose **Run**. For a command-line build, the unsigned debug bundle is under `.build/XcodeDerivedData/Build/Products/Debug/Workspace Orchestrator.app`.

The application is a menu-bar agent, so look for its grid icon in the menu bar rather than the Dock. Choose **Open Dashboard** to manage scenes.

## Demo Scene

1. Open the dashboard from the menu-bar item.
2. Click **Install Demo Scene**. Installation is explicit and does not run anything.
3. Inspect or edit the three actions.
4. Click **Run** only when ready. The demo opens TextEdit, opens `https://example.com`, then runs `/usr/bin/printf` with a harmless message.

## Process-action security

Process actions can run local executables with the permissions of the current user. Review every executable path, argument, and working directory before running an imported scene. The schema intentionally forbids arbitrary shell command strings and the implementation never invokes `/bin/sh -c`, `/bin/bash -c`, `/bin/zsh -c`, or equivalent wrappers.

## Screenshot

> Screenshot placeholder — no screenshot is claimed for Milestone 1. Add a verified dashboard image after manual UI inspection.

## Roadmap

Milestone 2 focuses on reliable orchestration; Milestone 3 on workspace restoration; Milestone 4 on activation; Milestone 5 on open-source release quality; and Milestone 6 explores an optional team layer. See the [full roadmap](docs/ROADMAP.md). Future milestones are not implemented.

Read [CONTRIBUTING.md](CONTRIBUTING.md) before proposing changes and report vulnerabilities according to [SECURITY.md](SECURITY.md).

Licensed under the [Apache License 2.0](LICENSE). Copyright 2026 Ahmad Memon.
