# ADR 0004: Deterministic bounded DAG orchestration

- Status: Accepted
- Date: 2026-08-12

## Context

The V1 product needs dependency-aware parallel actions, retries, checks, cancellation, deactivation, and truthful scene status. Keeping these rules in the macOS adapter layer would make them difficult to test and would couple policy to side effects.

## Decision

Add a Foundation-only `OrchestrationEngine` module between SceneCore and MacAutomation. It validates the complete scene before side effects, schedules ready actions in configured order, runs at most `maximumConcurrency` actions at a time, and derives skipped, failed, Ready, and Ready with warnings states from real terminal action records. Failed required dependencies never run their dependents.

Action execution, health checking, sleep, and retry jitter are protocols. Retry delay is bounded, cancellation interrupts action and retry sleeps, and tests inject deterministic implementations. MacAutomation supplies an action executor and keeps `Foundation.Process` and `NSWorkspace` behind existing protocols. V1 scenes migrate with concurrency one, preserving sequential behavior.

## Consequences

Scheduling and policy tests run without AppKit or real external applications. Platform integrations can be added as action executors without duplicating orchestration rules. The scheduler uses deterministic bounded batches; a later optimization may immediately refill a freed concurrency slot, but must preserve ordering, bounds, state semantics, and deterministic tests.
