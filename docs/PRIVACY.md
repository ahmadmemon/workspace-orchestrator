# Privacy

Workspace Orchestrator is local-first and single-user. V1 has no account, analytics, advertising, telemetry, crash-upload SDK, cloud synchronization, hosted API, or remote-control channel.

## Data stored locally

- Scene definitions and migration backups
- Exact process-approval fingerprints (not secret values)
- Live/interrupted run snapshots and bounded run history
- User preferences and optional activation configuration
- Secret values in macOS Keychain, referenced by identifier from scenes

Run records may contain paths, executable arguments, URLs, window titles, errors, stdout, and stderr. Redaction removes configured secret-like fields and output is bounded, but it cannot guarantee that arbitrary program output is nonsensitive. Review before export or sharing.

Double-clap detection converts bounded audio buffers into energy, peak duration, crossing/spectral ratios, and timestamps locally; it never stores raw audio. Calibration retains only aggregate ambient RMS statistics and representative peak/timing recommendations in memory, and persists sensitivity/timing only after explicit acceptance. The controlled test trace runs no scene. Detection pauses on reliability, clipping, permission, route, interruption, hardware, format, sleep, configuration, manual, and restart conditions; safe transient recovery is bounded, while persistent permission/hardware failures require intervention. Voice mode requests on-device recognition; no cloud fallback is permitted, and the in-memory transcript is cleared when the explicit session closes. Apple system services may have their own OS privacy behavior, which the permission sheet exposes before enabling.

If the user enables launch-time update checks or chooses Check for Updates Now, the app requests the latest release tag from the official GitHub Releases API. It sends no scene, history, diagnostic, device, or account data and does not download or install software.

Uninstalling the app does not automatically delete Application Support or Keychain data. See [Release](RELEASE.md) for removal steps. Report privacy/security issues privately according to [SECURITY.md](../SECURITY.md).
