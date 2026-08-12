# ADR 0006: Security persistence and direct release boundary

## Status

Accepted for V1 RC.

## Decision

Keep scene, approval, live-run, and bounded history data in separate atomic local stores. Preserve corrupt/migration input. Store secret values in Keychain and serialize only references. Bind process trust to an exact structured fingerprint. Distribute outside the Mac App Store as a hardened-runtime universal app with only the audio-input entitlement, Developer ID signing, notarization, checksum, dependency inventory, source revision, and toolchain record.

## Rationale

Separation limits accidental disclosure and lets recovery fail safely. Exact approvals avoid broad executable allowlists. Keychain avoids plaintext secrets in portable files. Direct distribution is necessary for explicit developer-tool/process orchestration, while signed/notarized artifacts retain the macOS trust chain.

## Consequences

Users must approve changed process details and recreate secret references after import. Accessibility/audio/Speech stay optional and permission-scoped. Release credentials remain external; unsigned archives may verify engineering but cannot satisfy the public distribution gate. Automatic updates are deferred pending a separate signed-metadata threat model.
