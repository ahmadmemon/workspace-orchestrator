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

Closed Codable enums and strict validation reject unknown/unsafe data. V1 migration preserves source bytes. Process requests are structured executable-plus-argument arrays, shell wrappers and privilege elevation are forbidden, and exact approval is required. Approval invalidates when the executable, argument boundaries/content, working directory, environment configuration or Keychain reference identifier, retry/timeout policy, or managed stop behavior changes; Keychain values remain outside the fingerprint. Secret labels can be replaced, renamed, repaired, or deleted without revealing existing values, and referenced deletion names the affected scene actions. Imports/capture are reviewed and never auto-run. Historical retry uses the immutable stored scene snapshot, reruns current validation/integration/approval/secret checks, previews the selected action set, and requires explicit execution; it never grants historical trust. DAG state, all/any enabled conditions, bounded readiness attempts, required/optional health results, explicit created/adopted ownership policy, staged interrupt/terminate/force-kill timing, cancellation, interruption snapshots, and durable records make partial outcomes visible. Permission-gated adapters limit Accessibility/audio/Speech use. Clap calibration/test retain aggregate features and bounded text only, never raw audio, and test mode cannot execute a scene. Ambiguous voice commands require confirmation. Scoped reset separates settings, scenes, history, secrets, layouts, and approvals behind typed confirmation. Release scripts generate a universal archive, checksum, dependency inventory, SPDX SBOM, revision, clean-tree state, and toolchain record; Developer ID/notarization are credential gates.

## Residual risks

An approved executable can still perform any action allowed to the user. Process output and window titles can contain unexpected secrets. Local executables may change after approval. Accessibility is inherently powerful. Audio environments can produce false positives. Health checks prove only configured conditions. Cancellation cannot guarantee termination of grandchildren created independently by a process. A checksum published beside a compromised artifact is not an independent trust root.

Users must inspect scenes and approval details, protect local accounts, obtain releases from the official repository, verify signing/notarization/checksum, and use conservative confirmation settings. Stable release requires the human and credential checks in [Smoke Test](SMOKE_TEST.md) and [Release](RELEASE.md).
