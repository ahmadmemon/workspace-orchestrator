# ADR 0003: Scene schema V2 and explicit migration

- Status: Accepted
- Date: 2026-08-12

## Context

V1 stored a scene as one ordered list containing three action payloads. Reliable orchestration and workspace restoration need stable dependency IDs, typed policies and checks, activation/deactivation plans, trust state, and additional strongly typed action families without losing V1 data.

## Decision

Schema V2 keeps the existing `actions` key as the activation plan, adds `deactivationActions`, and adds scene/action policy fields with safe defaults. The decoder accepts versions 1 and 2; V1 decodes into V2 with concurrency `1` so its sequential behavior is preserved. `JSONSceneStore` detects V1 bytes before decoding, writes those exact bytes to `migration-backups`, validates the migrated model, and then atomically writes V2. Unsupported future schemas and unknown actions fail closed.

Process-capable actions retain an absolute executable plus structured arguments. Generic shell/wrapper executables are rejected. Secret environment values are Keychain references, never embedded values. Imported archives are marked untrusted and produce a review inventory before they may be saved or approved.

## Consequences

Existing scenes preserve identifiers and order. Migration creates a recoverable local backup and surfaces failure without intentionally replacing the source file. V2 is larger, but its closed Codable model makes permissions, destructive behavior, dependencies, and approvals inspectable. Future schema changes require another explicit migration and test path.
