#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repository_root"
expected_version="${EXPECTED_VERSION:-1.0.0-rc.1}"
expected_build="${EXPECTED_BUILD:-1}"

settings="$(xcodebuild -project WorkspaceOrchestrator.xcodeproj -scheme WorkspaceOrchestratorApp -configuration Release -showBuildSettings)"
actual_version="$(awk -F ' = ' '/MARKETING_VERSION =/ { print $2; exit }' <<< "$settings")"
actual_build="$(awk -F ' = ' '/CURRENT_PROJECT_VERSION =/ { print $2; exit }' <<< "$settings")"

if [[ "$actual_version" != "$expected_version" ]]; then echo "Expected version $expected_version, found $actual_version"; exit 1; fi
if [[ "$actual_build" != "$expected_build" ]]; then echo "Expected build $expected_build, found $actual_build"; exit 1; fi
echo "Version verified: $actual_version ($actual_build)"
