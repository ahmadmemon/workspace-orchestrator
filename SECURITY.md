# Security Policy

## Supported versions

The project is pre-release. Only the latest `main` revision is currently supported with security fixes.

## Reporting a vulnerability

Do not open a public issue for a suspected vulnerability. Until a public security contact is established, contact the repository owner privately through GitHub. Include affected revision, impact, safe reproduction steps, and any suggested remediation. Do not include unrelated personal data or secrets.

Maintainers should acknowledge a report promptly, reproduce it in an isolated environment, keep the reporter informed, and coordinate disclosure after a fix is available.

## User safety

Imported scenes are untrusted. Review every action before saving or running it, particularly executable paths and arguments. Workspace Orchestrator does not elevate privileges and never requires a shell command string. See `docs/SECURITY_MODEL.md` for the detailed threat model.
