# Product Specification

## Product problem

Knowledge workers repeatedly reconstruct a project context across applications, URLs, terminals, services, and windows. The sequence is slow, error-prone, and provides no single answer to “is my workspace ready?” Existing automation often relies on opaque shell scripts or broad permissions.

## Product vision

Workspace Orchestrator makes a workspace a reusable, observable scene. Activating one eventually restores the right tools and state, checks readiness, and communicates progress through a polished macOS experience. The foundation is local-first, inspectable, deterministic, and secure by design.

## Target users

- Developers switching among repositories and toolchains
- Designers, researchers, and operators with repeatable multi-application workspaces
- Automation-conscious macOS users who want visibility and control

## Core user stories

- As a user, I can define an ordered scene without writing a shell command.
- As a user, I can inspect and validate every action before saving or running.
- As a user, I can start or cancel a scene from the menu bar.
- As a user, I can see the current action, timing, output, and exact failure.
- As a user, I can keep scenes locally without creating an account.

## Milestone 1 scope

The native menu-bar app provides scene CRUD, explicit demo installation, local JSON persistence, sequential execution, cancellation, and status reporting for exactly three actions: open application, open HTTP(S) URL, and run a structured process.

## Non-goals

No parallelism, dependency graph, retries, checks, workspace capture/restoration, Docker or tool-specific integration, window manipulation, accessibility automation, AppleScript, browser automation, activation gestures, voice, AI, cloud, accounts, payment, telemetry, updating, signing, or distribution workflow is included.

## Functional requirements

1. Decode only schema version 1 and the closed set of three action types.
2. Validate IDs, names, bundle identifiers, URLs, executable paths, working directories, and timeouts.
3. Persist CRUD operations atomically in Application Support without destroying corrupt data.
4. Execute in order, stop after failure, capture process results, and support cancellation.
5. Display saved scenes and detailed live/latest execution state.
6. Never install or execute the demo without direct user choice.

## Reliability requirements

Errors must be explicit and actionable. A failed action leaves later actions pending. Cancellation produces cancelled state. Persistence supports a missing directory and empty collection. Core behavior has deterministic automated tests, and every accepted change must preserve a passing native build.

## Security requirements

Treat scenes as untrusted; reject unknown schema/action types; never elevate privileges or run shell strings; limit URLs to HTTP(S); inject all side effects; request no broad permissions; commit no secrets; and add no telemetry or cloud dependency without approval.

## Privacy requirements

Scenes remain on the Mac. No analytics, accounts, or network backend exists. Process output is potentially sensitive and must not be transmitted. UI and documentation warn users before sharing logs.

## Accessibility considerations

Use native SwiftUI controls, semantic labels, keyboard-reachable actions, clear text status in addition to color, and understandable errors. Future manual testing should include VoiceOver, reduced motion, increased contrast, Dynamic Type behavior where applicable, and keyboard-only scene editing.

## Long-term direction

After manual acceptance of the foundation, improve orchestration reliability, then restore full workspaces, add explicit activation experiences, complete signing/release quality, and only later explore an optional encrypted team layer. Each stage must retain local control and observable execution.
