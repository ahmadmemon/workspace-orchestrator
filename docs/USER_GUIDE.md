# User Guide

## Scenes and actions

A scene is a named, stable-ID workspace with activation actions and optional deactivation actions. Actions may depend on other action IDs. Independent ready actions can run in parallel up to the scene limit; visual list order remains the deterministic tie-breaker.

Use Scene Builder to add supported actions and edit their typed fields. A required action normally stops dependent work on failure. Continue-degraded, continue-optional, and skip-dependents policies change that behavior explicitly. Retry policy defines bounded attempts and fixed or exponential delay with optional jitter and typed retryable categories. Conditions can require an absolute path or an exact environment value; choose whether all or any enabled conditions must match. Health checks determine readiness after execution. HTTP, TCP, file/directory, managed-process, application, and Docker-service checks expose bounded timeout/interval/attempt policy and can be required or optional.

One-shot and managed processes use a structured argument editor. Each row is one exact argument; empty strings, whitespace, tabs, and literal newlines are preserved. Reorder with the Move Up and Move Down buttons. The copyable preview is JSON containing an executable and argument array—not shell syntax—and execution continues to pass the array directly to the process API.

## Activating and stopping

Activation validates again and requests exact approval for untrusted process-bearing actions. Current Run shows preparing, running, waiting, checking, retrying, ready, degraded, failed, cancelled, stopping, and interrupted state. Cancel asks active work to stop; deactivation executes the scene's explicit stop actions and stops only resources the run identifies as owned unless policy says otherwise.

If the app closes during a run, the next launch reports an interrupted snapshot. Inspect it and choose a fresh action; Workspace Orchestrator does not silently resume or claim readiness.

## Dashboard and command access

The dashboard provides scene cards, recent status, navigation, capture, integration/permission state, and the Workspace Core status visual. The menu-bar view offers favorite/recent activation, current progress, stop/cancel, dashboard, command palette, settings, and quit. The command palette supports keyboard-first navigation and activation.

## Optional activation

The global shortcut registers a configured key combination and does not log keys. Double-clap performs local transient-feature detection after microphone opt-in. Guided calibration explains local processing, samples ambient features for five seconds, requests one representative double clap, and recommends sensitivity plus a timing range. Review or adjust those values and choose **Accept Calibrated Settings**; cancellation saves nothing. Test mode displays listening, transient, first-clap, waiting, rejection, cooldown, success, and stopped states but is structurally unable to run a scene. Detection pauses with the exact reason after false detections, sustained noise, repeated clipping, permission or hardware loss, route/format changes, interruptions, sleep, configuration changes, manual pause, and relaunch. Safe transient failures receive at most two recovery attempts with the existing audio engine; persistent hardware/permission failures require the user to resolve the condition and resume. Scene activation can require a confirmation before any action executes. Voice commands use on-device recognition and require exact or confirmed scene matching. During an explicitly started voice session, the configured activation phrase may prefix a command, for example “Workspace online, run Project H”; direct commands remain available as an accessibility-friendly alternative. Spoken status announces derived run state. Every service may be disabled independently.

## Settings, secrets, and reset

Settings are persisted locally and affect the behavior they describe. Startup controls cover login launch, Dashboard opening, interrupted-run recovery, notifications, and an optional official-release version check. Menu settings bound favorites and control recent/current-run sections. Appearance intensity is capped by system Reduce Motion, Reduce Transparency, and Increase Contrast. Execution defaults apply only to newly authored scenes/actions; existing scenes are not rewritten. Managed processes use separate interrupt and terminate windows before force kill, and the safe ownership default stops only resources created by the run.

Keychain management lists user labels and every saved scene/action/environment reference without revealing the value. You can create, replace, rename, or repair a label. Referenced deletion requires confirmation naming affected scenes; references remain in place so they can be repaired. Copying stored values is unavailable. Advanced reset uses separate category toggles plus typed `RESET`; unselected settings, scenes, valid history, Keychain secrets, window layouts, and approvals remain untouched, and corrupt history is preserved.

## Capture, imports, and history

Capture starts from discoverable running applications, excludes Workspace Orchestrator and known sensitive apps by default, and includes windows only with Accessibility permission. Review and edit the draft before saving; capture never runs it. Imports show schema, duplicate, warning, and risky-action information and remain untrusted. Exported archives omit Keychain secret values and trust grants.

History is local and bounded by the configured age and run-count limits. Filter by scene, terminal status, preset local-calendar ranges, or a custom inclusive date range. Opening a run shows its immutable scene snapshot, action attempts, timing, output excerpts, health checks, errors, and resource ownership. A retry never silently substitutes the current scene: choose the full stored snapshot or failed actions plus their dependents, inspect current validation, integration, approval, and secret-reference preflight, then explicitly run. You can also save the historical snapshot as a new editable scene. Per-run deletion and valid-history clearing leave corrupt files preserved for recovery. Diagnostic export is bounded and redacted, but output can still contain private data; inspect it before sharing.

## Recovery and errors

Errors identify the failed action, reason, effect on dependents, suggested next step, and resources that may remain. Correct the scene/tool/permission, then activate again. Repeated runs use idempotency policy to reuse or restart resources deliberately; they do not blindly duplicate managed work.
