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

Confirm the feature is enabled, permission is granted, and the active indicator is present. Clap detection needs two distinct transients within its configured interval and may reject noise. Voice requires on-device Speech availability and an unambiguous scene name. Use the global shortcut as the accessible fallback.

## Run is interrupted, degraded, or cannot cancel fully

An interrupted state means the app ended before completion; inspect potentially owned resources and activate/deactivate deliberately. Degraded means an explicitly nonrequired action/check failed. Cancellation stops tracked work, but independently spawned child processes may require manual cleanup.

## Persistence error

Do not overwrite the file. Corrupt data is deliberately preserved under `~/Library/Application Support/WorkspaceOrchestrator`; copy it before recovery. Diagnostics may reveal the affected filename but can contain private paths.

## Build problems

Use macOS 14+, Xcode 15.4+, and a Swift 5.10-compatible toolchain. If SwiftPM reports an ABI/cache crash after changing public models, run `swift package clean` and rebuild. This removes derived package products, not source or user data.
