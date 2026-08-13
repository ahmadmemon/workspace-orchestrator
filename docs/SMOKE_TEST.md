# Manual Smoke Test

Record macOS version, hardware architecture, display arrangement, app revision, signature/notarization result, and tester. Use disposable scenes and nonsecret files.

## Installation and native experience

- [ ] Notarized ZIP checksum matches and Gatekeeper accepts a clean-machine install
- [ ] Menu-bar item, dashboard, Settings, About, command palette, sheets, focus, shortcuts, and quit behave natively
- [ ] Onboarding can complete with every optional permission skipped and can be revisited/reset
- [ ] App icon is crisp at menu, Finder, Dock/About, and Accessibility sizes
- [ ] Light/dark system appearance, increased contrast, Reduce Motion, and Reduce Transparency remain legible
- [ ] Keyboard-only and VoiceOver navigation reaches every primary action with sensible labels/order

## Core workflow

- [ ] Create, edit, reorder, duplicate, favorite, validate, save, export, import-review, and delete a scene
- [ ] Install the demo explicitly; confirm it neither auto-runs nor bypasses process approval
- [ ] Run dependency/parallel/retry/health/failure/cancel/deactivate flows and confirm status/history match observed effects
- [ ] Force app termination during a safe wait and confirm interrupted recovery is truthful
- [ ] Confirm output redaction/retention and history cleanup with deliberately nonsecret markers

## Integrations and windows

- [ ] Test installed app, browser, file/folder, each available editor/terminal, Docker Compose, and Shortcuts using harmless fixtures
- [ ] Verify unavailable tools/paths/projects fail with actionable guidance
- [ ] Grant/deny/revoke Accessibility and verify capture/layout behavior and settings link
- [ ] Review capture exclusions, edit the draft, save it, and confirm it never auto-runs
- [ ] Test one/two displays, moved displays, scaled resolutions, unmatched/duplicate titles, minimized/full-screen windows

## Activation and platform services

- [ ] Register/change/conflict-test the global shortcut; ensure no keystroke logging behavior
- [ ] Grant/deny/revoke microphone; verify guided ambient + representative-clap calibration, accept/adjust/cancel persistence, test-mode states/reasons without execution, cooldown, quiet/noisy/clipped input, manual pause, bounded device/route/interruption/format recovery, persistent failure, relaunch state, and disabled state
- [ ] Grant/deny/revoke Speech; test exact, fuzzy, ambiguous, cancel/stop/navigation phrases and offline/on-device unavailability
- [ ] Verify spoken status and notifications are optional, accurate, and disabled when requested
- [ ] Enable/disable launch at login and verify after a real login
- [ ] Confirm visible indicators whenever audio/voice services are active

## Security and release

- [ ] Imported and edited process fingerprints require fresh approval; approve-once is consumed
- [ ] Shell wrappers, `sudo`, invalid URLs, control characters, unsafe Docker requests, and unknown schema/action values fail closed
- [ ] Keychain secrets are absent from scene/archive/history/diagnostic files
- [ ] No network traffic occurs except explicit URL/HTTP/TCP actions and Apple OS services enabled by the tester
- [ ] Verify universal architectures, hardened runtime, entitlements, signature, notarization, stapling, checksum, inventory, revision, and toolchain files

Any unchecked item blocks stable V1. Attach screenshots/log excerpts only after removing private data.

Run automated macOS UI acceptance on an unlocked interactive desktop. A locked session is not a valid UI-test result because XCTest cannot attach to the app accessibility hierarchy even when its windows render.
