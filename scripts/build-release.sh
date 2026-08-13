#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repository_root"

version="${RELEASE_VERSION:-1.0.0-rc.1}"
build_number="${RELEASE_BUILD:-1}"
output_root="${OUTPUT_DIR:-$repository_root/dist/$version}"
archive_path="$output_root/WorkspaceOrchestrator.xcarchive"
derived_data="$output_root/DerivedData"
app_name="Workspace Orchestrator.app"
zip_name="Workspace-Orchestrator-$version.zip"

source_state="clean"
if ! git diff --quiet || ! git diff --cached --quiet || [[ -n "$(git ls-files --others --exclude-standard)" ]]; then
  source_state="dirty"
  if [[ "${ALLOW_DIRTY_RELEASE:-0}" != "1" ]]; then
    echo "Release packaging requires a clean source tree. Commit or stash changes first."
    exit 1
  fi
  echo "Warning: creating a non-publishable verification artifact from a dirty source tree."
fi

if [[ -e "$output_root" ]]; then echo "Output already exists: $output_root"; echo "Choose a new OUTPUT_DIR to avoid overwriting release artifacts."; exit 1; fi
mkdir -p "$output_root"

"$repository_root/scripts/verify-version.sh"
"$repository_root/scripts/security-audit.sh"
swift test

signing_arguments=(CODE_SIGNING_ALLOWED=YES CODE_SIGNING_REQUIRED=YES CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=-)
if [[ -n "${DEVELOPER_ID_APPLICATION:-}" ]]; then
  signing_arguments=(CODE_SIGNING_ALLOWED=YES CODE_SIGN_STYLE=Manual "CODE_SIGN_IDENTITY=$DEVELOPER_ID_APPLICATION")
fi

xcodebuild archive \
  -project WorkspaceOrchestrator.xcodeproj \
  -scheme WorkspaceOrchestratorApp \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$archive_path" \
  -derivedDataPath "$derived_data" \
  ARCHS='arm64 x86_64' \
  ONLY_ACTIVE_ARCH=NO \
  MARKETING_VERSION="$version" \
  CURRENT_PROJECT_VERSION="$build_number" \
  "${signing_arguments[@]}"

app_path="$archive_path/Products/Applications/$app_name"
if [[ ! -d "$app_path" ]]; then echo "Archive did not contain $app_path"; exit 1; fi
lipo -info "$app_path/Contents/MacOS/Workspace Orchestrator"
codesign --verify --deep --strict "$app_path"
if [[ -z "${DEVELOPER_ID_APPLICATION:-}" ]]; then
  echo "Ad-hoc integrity signature verified; Developer ID trust and notarization remain credential-gated."
fi

cat > "$output_root/dependency-inventory.json" <<EOF
{
  "application": "Workspace Orchestrator",
  "version": "$version",
  "build": "$build_number",
  "minimumMacOS": "14.0",
  "architectures": ["arm64", "x86_64"],
  "thirdPartyRuntimeDependencies": [],
  "appleFrameworks": ["AppKit", "SwiftUI", "Foundation", "ApplicationServices", "AVFoundation", "Speech", "Security", "Network", "ServiceManagement", "UserNotifications"]
}
EOF

cat > "$output_root/sbom.spdx.json" <<EOF
{
  "spdxVersion": "SPDX-2.3",
  "dataLicense": "CC0-1.0",
  "SPDXID": "SPDXRef-DOCUMENT",
  "name": "Workspace-Orchestrator-$version",
  "documentNamespace": "https://github.com/ahmadmemon/workspace-orchestrator/releases/$version/sbom",
  "creationInfo": {
    "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "creators": ["Tool: scripts/build-release.sh"]
  },
  "packages": [{
    "name": "Workspace Orchestrator",
    "SPDXID": "SPDXRef-Package-WorkspaceOrchestrator",
    "versionInfo": "$version",
    "downloadLocation": "NOASSERTION",
    "filesAnalyzed": false,
    "licenseConcluded": "Apache-2.0",
    "licenseDeclared": "Apache-2.0",
    "copyrightText": "Copyright 2026 Ahmad Memon",
    "externalRefs": []
  }]
}
EOF

git rev-parse HEAD > "$output_root/source-revision.txt"
printf '%s\n' "$source_state" > "$output_root/source-tree-state.txt"
xcodebuild -version > "$output_root/toolchain.txt"
swift --version >> "$output_root/toolchain.txt"

ditto -c -k --sequesterRsrc --keepParent "$app_path" "$output_root/$zip_name"

if [[ -n "${NOTARY_KEYCHAIN_PROFILE:-}" ]]; then
  xcrun notarytool submit "$output_root/$zip_name" --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" --wait
  xcrun stapler staple "$app_path"
  xcrun stapler validate "$app_path"
  rm "$output_root/$zip_name"
  ditto -c -k --sequesterRsrc --keepParent "$app_path" "$output_root/$zip_name"
else
  echo "Notarization skipped: NOTARY_KEYCHAIN_PROFILE is not configured."
fi

(cd "$output_root" && shasum -a 256 "$zip_name" dependency-inventory.json sbom.spdx.json source-revision.txt source-tree-state.txt toolchain.txt > SHA256SUMS.txt)

echo "Release artifacts: $output_root"
