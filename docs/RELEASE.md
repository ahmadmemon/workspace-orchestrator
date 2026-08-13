# Release Process

## Version and prerequisites

RC1 is `1.0.0-rc.1` build `1`, minimum macOS 14, universal `arm64`/`x86_64`, direct distribution, hardened runtime, and no third-party runtime dependencies. A public release requires an Apple Developer ID Application identity, notarization credentials stored in a local/CI Keychain profile, and a clean verified revision.

## Local verification and packaging

```bash
scripts/verify-version.sh
scripts/security-audit.sh
swift package clean
swift build --target SceneCore
swift build
swift test
xcodebuild -project WorkspaceOrchestrator.xcodeproj -scheme WorkspaceOrchestratorApp -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/XcodeDerivedData CODE_SIGNING_ALLOWED=NO build
xcodebuild -project WorkspaceOrchestrator.xcodeproj -scheme WorkspaceOrchestratorApp -configuration Release -destination 'platform=macOS' -derivedDataPath .build/XcodeDerivedData CODE_SIGNING_ALLOWED=NO ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO build
OUTPUT_DIR=/absolute/new/output scripts/build-release.sh
```

The package script refuses to overwrite output or package a dirty tree. It reruns version/security/tests, creates an archive, checks architecture, packages the app, and writes `SHA256SUMS.txt`, `dependency-inventory.json`, `sbom.spdx.json`, `source-revision.txt`, `source-tree-state.txt`, and `toolchain.txt`. `ALLOW_DIRTY_RELEASE=1` exists only for local non-publishable verification and records `dirty` in the provenance.

## Signing and notarization

Configure credentials outside the repository, then run:

```bash
DEVELOPER_ID_APPLICATION='Developer ID Application: …' \
NOTARY_KEYCHAIN_PROFILE='workspace-orchestrator-notary' \
OUTPUT_DIR=/absolute/new/output \
scripts/build-release.sh
```

The script verifies the signed bundle, submits the ZIP with `notarytool --wait`, staples the ticket, and validates it. Inspect with `codesign -dv --verbose=4`, `spctl --assess --type execute --verbose=4`, and `xcrun stapler validate`. Never pass certificate/private-key material through source, logs, or workflow files.

## Candidate publication

Push `feat/v1-release-candidate`, open an unmerged PR against `main`, wait for CI, resolve failures, and complete [Smoke Test](SMOKE_TEST.md). Only after review may a maintainer create an annotated RC tag and GitHub prerelease with ZIP, checksum, inventory, revision/toolchain records, changelog, known limitations, and minimum OS. Do not publish `1.0.0` until every stable-release gate passes.

## Installation and removal

For a notarized release, verify the checksum, move the app to `/Applications`, open it normally, and confirm Gatekeeper accepts the signature. To remove it, disable launch at login and activation services, quit, delete the app, then optionally remove `~/Library/Application Support/WorkspaceOrchestrator` and related Keychain items after backing up scenes. These data are not silently deleted.

## Update strategy

RC1 has no automatic downloader or installer. When the user enables launch-time checks or presses **Check for Updates Now**, it requests only the latest release tag from the official GitHub Releases API and reports availability; it sends no workspace data and never installs software. Users explicitly download releases from the official repository and review notes, checksum, and signature. Any future automatic updater requires a separate threat/privacy design, signed metadata, rollback, and opt-in behavior.
