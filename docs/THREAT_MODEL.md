# Threat Model

## Assets

User files and credentials, Keychain secrets, process authority, scene integrity, run/history privacy, window metadata, activation privacy, and release authenticity.

## Adversaries and failure sources

- A malicious or misleading imported scene
- A hand-edited/corrupt scene or persistence file
- A legitimate executable invoked with dangerous arguments
- A compromised local integration or executable path
- Accidental secret disclosure through output, URL, title, or diagnostics
- False clap/voice activation or an ambiguous spoken scene name
- Accessibility misuse or incorrect window matching
- Dependency/health races, app termination, or partial cleanup
- Tampered or unsigned distribution artifacts

## Mitigations

Closed Codable enums and strict validation reject unknown/unsafe data. V1 migration preserves source bytes. Process requests are structured, shell wrappers and privilege elevation are forbidden, and exact approval is required. Secret references resolve through Keychain. Imports/capture are reviewed and never auto-run. DAG state, bounded retries/timeouts, resource ownership, cancellation, interruption snapshots, and durable records make partial outcomes visible. Permission-gated adapters limit Accessibility/audio/Speech use. Ambiguous voice commands require confirmation. Release scripts generate a universal archive, checksum, dependency inventory, revision, and toolchain record; Developer ID/notarization are credential gates.

## Residual risks

An approved executable can still perform any action allowed to the user. Process output and window titles can contain unexpected secrets. Local executables may change after approval. Accessibility is inherently powerful. Audio environments can produce false positives. Health checks prove only configured conditions. Cancellation cannot guarantee termination of grandchildren created independently by a process. A checksum published beside a compromised artifact is not an independent trust root.

Users must inspect scenes and approval details, protect local accounts, obtain releases from the official repository, verify signing/notarization/checksum, and use conservative confirmation settings. Stable release requires the human and credential checks in [Smoke Test](SMOKE_TEST.md) and [Release](RELEASE.md).
