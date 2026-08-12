# Product Specification

## Product promise

Workspace Orchestrator lets a macOS user restore a complex local workspace as one inspected scene and answers, truthfully, whether it became ready. It is designed for developers and other multi-application knowledge workers who need repeatability without replacing transparent configuration with opaque shell scripts.

## V1 experience

The menu-bar app opens the Workspace Core dashboard. Users create or import scenes, configure typed actions in the Scene Builder, preview permissions and approvals, activate or deactivate a scene, inspect current progress, and review durable local history. A command palette and optional global shortcut reduce navigation time. Optional clap and voice input remain off until explicitly enabled.

The scene model supports applications, HTTP(S) browser workspaces, files/folders, one-shot processes, managed processes, bounded waits, VS Code-family workspaces, Terminal/iTerm workspaces, Docker Compose projects, macOS Shortcuts, and reviewed window layouts. Dependencies and policies describe intent without exposing arbitrary shell syntax.

## Core requirements

1. Treat every decoded or imported scene as untrusted and validate before save and every execution.
2. Migrate V1 scene data to V2 without silently discarding the original bytes.
3. Execute valid dependency graphs deterministically with bounded concurrency, cancellation, retries, conditions, checks, and visible policy outcomes.
4. Require exact approval before a process-bearing action whose fingerprint is not trusted.
5. Keep scene definitions, approvals, live state, and bounded history locally; store secret values in Keychain.
6. Make capture a reviewed draft. Never save or execute captured content automatically.
7. Degrade safely when a tool, display, file, health target, or optional permission is unavailable.
8. Expose real state only: no simulated integrations, fabricated metrics, hidden fallbacks, or silent errors.

## Experience requirements

- Native keyboard, menu, window, focus, VoiceOver, contrast, Reduce Motion, and Reduce Transparency behavior
- Distinguishable idle, preparing, running, waiting, checking, retrying, ready, degraded, failed, cancelled, stopping, and interrupted states using text and symbols as well as color
- Errors explain what failed, why, impact, next action, and whether resources remain running
- Destructive actions require confirmation; imported and process actions receive elevated review
- Menubar controls remain compact while the dashboard provides full inspection

## Privacy and permissions

Local operation requires no account. There is no analytics SDK or hosted backend. Accessibility is requested only for reviewed window features. Microphone and Speech are requested only when the corresponding local activation mode is enabled. Notifications and launch at login are optional. Camera, Full Disk Access, administrator access, input monitoring, and screen recording are not V1 requirements.

## Release acceptance

The release candidate must pass package builds/tests, unsigned Debug and Release Xcode builds, universal archive packaging, security-pattern checks, schema migration/recovery tests, and documentation checks. Developer ID signing/notarization and human visual, VoiceOver, permission, real-integration, and audio testing are explicit external gates before stable V1.

## Non-goals

V1 excludes AI-generated scenes, cloud synchronization, accounts, team collaboration, remote execution, payments, analytics, browser scripting, arbitrary plug-ins, automatic updates, AppleScript automation, and silent privilege acquisition. These cannot be inferred from the V1 architecture or enabled without a separately reviewed milestone.
