# AGENTS.md

## Product purpose

Workspace Orchestrator is a local-first native macOS application that activates saved workspace scenes and reports exactly what happened. Milestone 1 supports three sequential actions only: opening an application, opening an HTTP(S) URL, and running an executable with a structured argument array.

Do not silently expand the active milestone. Read `PROJECT_STATUS.md` and `docs/ROADMAP.md` before choosing work.

## Architectural boundaries

- **SceneCore** must remain independent of SwiftUI and AppKit. It owns stable Codable schemas, validation, run-state/result models, and persistence.
- **MacAutomation** owns macOS/Foundation side effects and `SceneExecutor`. Every side effect must sit behind a mockable protocol.
- **WorkspaceOrchestratorApp** owns SwiftUI presentation and observable application state. Views must not execute processes, access `NSWorkspace`, or implement orchestration.

Dependencies flow from the app to both modules and from MacAutomation to SceneCore. SceneCore depends only on Foundation.

## Directory map

- `App/WorkspaceOrchestratorApp/`: app entry point, menu bar, dashboard, scene editor, app model
- `Packages/SceneCore/Sources/SceneCore/`: models, validation, run state, persistence
- `Packages/MacAutomation/Sources/MacAutomation/`: adapter protocols, native adapters, executor
- `Tests/SceneCoreTests/`: serialization, validation, persistence
- `Tests/MacAutomationTests/`: process and executor behavior; real app/browser opening is forbidden
- `Examples/`: non-runtime example data
- `docs/`: product, architecture, security, roadmap, and decisions
- `.github/`: CI and contribution templates

## Build instructions

From the repository root:

```bash
swift build --target SceneCore
swift build
xcodebuild -project WorkspaceOrchestrator.xcodeproj -scheme WorkspaceOrchestratorApp -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/XcodeDerivedData CODE_SIGNING_ALLOWED=NO build
```

## Test instructions

```bash
swift test
```

Tests must never launch applications or open URLs. Use mocks for `ApplicationOpening` and `URLOpening`. Directly testing harmless process execution is acceptable when the executable and arguments are explicit.

## Coding rules

- Prefer clear Swift over clever Swift.
- Keep UI separate from orchestration logic.
- Use structured concurrency appropriately.
- Avoid global mutable state.
- Dependency-inject side effects.
- Use strong types.
- Keep Codable schemas backwards-conscious; change `schemaVersion` deliberately.
- Handle errors explicitly and never swallow errors silently.
- Preserve action order unless a future approved milestone changes execution semantics.
- Keep changes small enough to review and test.

## Security rules

- Never use `sudo`.
- Never run arbitrary shell command strings.
- Never invoke shell wrappers for scene commands.
- Treat all scene files as untrusted input and validate before saving or execution.
- Never commit secrets.
- Never add telemetry without explicit approval.
- Never add cloud dependencies without an approved milestone.
- Do not request Accessibility, microphone, camera, or Full Disk Access during Milestone 1.
- Preserve corrupt persistence data and surface understandable failures.

## Dependency policy

Third-party dependencies require documented justification. Do not introduce one merely to avoid implementing a small amount of native functionality. Prefer Apple-native frameworks and standard-library capabilities.

## Definition of done

A task is not done until:

- Code is implemented.
- Relevant tests exist and pass.
- The application builds.
- Documentation is updated.
- `PROJECT_STATUS.md` is updated.
- `git diff` and `git status` are reviewed.

## Codex behavior

Future Codex sessions must:

1. Inspect the repository before editing.
2. Read this file.
3. Read `PROJECT_STATUS.md`.
4. Read the relevant roadmap milestone.
5. Preserve existing architecture unless there is a documented reason to change it.
6. Run tests.
7. Run the build.
8. Report exact observed results.
9. Never claim success without verification.
10. Never silently expand milestone scope.
