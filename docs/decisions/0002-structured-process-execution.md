# ADR 0002: Structured process execution

- Status: Accepted
- Date: 2026-08-09

## Context

Workspace scenes need to start local commands. A single shell string is convenient but introduces quoting ambiguity, injection, shell expansion, redirection, pipelines, startup configuration, and platform-dependent interpretation.

## Decision

Represent a process action as an absolute executable path plus an ordered argument array, optional absolute working directory, and optional positive timeout. Execute it directly with Foundation `Process`. Never pass scene commands to a shell wrapper.

## Consequences

Scene files are explicit, Codable, testable, and resistant to shell injection. Users cannot express pipelines or shell built-ins directly; a future feature would need a separately reviewed, explicitly approved model rather than weakening this boundary.
