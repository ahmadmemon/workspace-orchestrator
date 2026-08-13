# Security Policy

## Supported versions

The project is pre-release. The latest `main` revision and most recently published V1 release candidate, if any, receive security fixes.

## Reporting a vulnerability

Do not open a public issue for a suspected vulnerability. Until a public security contact is established, contact the repository owner privately through GitHub. Include affected revision, impact, safe reproduction steps, and any suggested remediation. Do not include unrelated personal data or secrets.

Maintainers should acknowledge a report promptly, reproduce it in an isolated environment, keep the reporter informed, and coordinate disclosure after a fix is available.

## User safety

Imported scenes are untrusted. Review every action, dependency, URL, path, executable, argument, environment reference, and stop policy before saving or running. Exact process approval does not make an executable harmless. Workspace Orchestrator does not elevate privileges and never accepts a shell command string. See `docs/SECURITY_MODEL.md` and `docs/THREAT_MODEL.md`.
