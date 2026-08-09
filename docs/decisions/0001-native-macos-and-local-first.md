# ADR 0001: Native macOS and local-first

- Status: Accepted
- Date: 2026-08-09

## Context

Workspace restoration requires reliable access to macOS application launching, process execution, windows, displays, input activation, and platform permissions. Workspace definitions and process output may be sensitive and should not require a remote service.

## Decision

Build macOS first with Swift and SwiftUI, using AppKit only for platform gaps. Store user scenes locally and require no account, cloud service, or network backend. Keep the product name and application identifiers easy to change.

## Consequences

The application integrates naturally with macOS conventions, has a small dependency surface, and can use structured concurrency and native APIs. It does not provide cross-platform support or cloud synchronization. Platform-specific behavior stays in MacAutomation so SceneCore remains portable pure Swift domain logic.
