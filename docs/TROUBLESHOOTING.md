# Troubleshooting

## Scene will not save

Open the validation details and correct the referenced field. Common causes are duplicate/missing action IDs, dependency cycles, invalid URLs/paths, restricted executables, control characters, unsafe Docker settings, invalid timeouts/retries, or window frames outside normalized bounds.

## Process approval keeps appearing

Approval is bound to the exact executable, arguments, working directory, and environment references. Any edit correctly invalidates it. A one-time approval is consumed after use. Imported scenes start untrusted.

## Integration is unavailable

Check the Integrations screen, install/configure the tool independently, and verify the expected CLI/application exists. Workspace Orchestrator does not install tools or credentials. Docker/project health and editor CLI availability are distinct from discovery.

## Window capture or placement fails

Grant Accessibility only if you want window features, then refresh/retry. Some applications expose incomplete window metadata. Changed displays or titles can cause fallback/unmatched warnings; review normalized placement and matching rules.

## Clap or voice does not work

Confirm the feature is enabled, permission is granted, and read the exact detector state in Settings. Run Guided Calibration in a representative room, remain quiet during the bounded ambient phase, then perform one normal double clap. Review/adjust and explicitly accept the recommendation. Nonexecuting Test explains too-quiet, clipped, timing, speech/noise, and cooldown rejection without running a scene. Route, interruption, format, device, or sleep failures use bounded recovery; permission denial or persistent hardware failure stays paused until resolved and explicitly resumed. Voice requires on-device Speech availability and an unambiguous scene name. Use the global shortcut as the accessible fallback.

## Run is interrupted, degraded, or cannot cancel fully

An interrupted state means the app ended before completion; inspect potentially owned resources and activate/deactivate deliberately. Degraded means an explicitly nonrequired action/check failed. Cancellation stops tracked work, but independently spawned child processes may require manual cleanup.

## Historical retry is blocked

A stored run is evidence, not an approval. Open its retry preview and resolve every current validation, integration, process-approval, or Keychain-reference issue. If the old snapshot is no longer appropriate, save it as a new scene and edit that copy. Missing or corrupt snapshots are preserved and cannot be executed.

## Keychain reference is missing

Settings shows labels and scene/action usages but never values. Repair or replace the same label to preserve scene references, or rename it to rewrite known saved-scene references. Deletion leaves references visible for later repair and requires confirmation when scenes are affected.

## Persistence error

Do not overwrite the file. Corrupt data is deliberately preserved under `~/Library/Application Support/WorkspaceOrchestrator`; copy it before recovery. Diagnostics may reveal the affected filename but can contain private paths.

## Build problems

Use macOS 14+, Xcode 15.4+, and a Swift 5.10-compatible toolchain. If SwiftPM reports an ABI/cache crash after changing public models, run `swift package clean` and rebuild. This removes derived package products, not source or user data.

macOS UI tests require an unlocked interactive desktop. A locked Mac may still show launched app windows in system window records while XCTest cannot attach to the SwiftUI accessibility hierarchy.
