# User Guide

## Scenes and actions

A scene is a named, stable-ID workspace with activation actions and optional deactivation actions. Actions may depend on other action IDs. Independent ready actions can run in parallel up to the scene limit; visual list order remains the deterministic tie-breaker.

Use Scene Builder to add supported actions and edit their typed fields. A required action normally stops dependent work on failure. `continue`, `skipDependents`, and `rollback` policies change that behavior explicitly. Retry policy defines maximum attempts, fixed/linear/exponential delay, jitter, and retryable categories. Conditions can require a path or environment value. Health checks determine readiness after execution.

## Activating and stopping

Activation validates again and requests exact approval for untrusted process-bearing actions. Current Run shows preparing, running, waiting, checking, retrying, ready, degraded, failed, cancelled, stopping, and interrupted state. Cancel asks active work to stop; deactivation executes the scene's explicit stop actions and stops only resources the run identifies as owned unless policy says otherwise.

If the app closes during a run, the next launch reports an interrupted snapshot. Inspect it and choose a fresh action; Workspace Orchestrator does not silently resume or claim readiness.

## Dashboard and command access

The dashboard provides scene cards, recent status, navigation, capture, integration/permission state, and the Workspace Core status visual. The menu-bar view offers favorite/recent activation, current progress, stop/cancel, dashboard, command palette, settings, and quit. The command palette supports keyboard-first navigation and activation.

## Optional activation

The global shortcut registers a configured key combination and does not log keys. Double-clap performs local transient-feature detection after microphone opt-in; use confirmation where false activation would be disruptive. Voice commands use on-device recognition and require exact or confirmed scene matching. Spoken status announces derived run state. Every service may be disabled independently.

## Capture, imports, and history

Capture starts from discoverable running applications, excludes Workspace Orchestrator and known sensitive apps by default, and includes windows only with Accessibility permission. Review and edit the draft before saving; capture never runs it. Imports show schema, duplicate, warning, and risky-action information and remain untrusted. Exported archives omit Keychain secret values and trust grants.

History is local and bounded. Output can contain private data even after redaction, so inspect exported or copied diagnostics before sharing.

## Recovery and errors

Errors identify the failed action, reason, effect on dependents, suggested next step, and resources that may remain. Correct the scene/tool/permission, then activate again. Repeated runs use idempotency policy to reuse or restart resources deliberately; they do not blindly duplicate managed work.
