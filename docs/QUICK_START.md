# Quick Start

1. Build and run `WorkspaceOrchestratorApp` from Xcode on macOS 14+, or install a signed/notarized release when one is published.
2. Open the grid item in the menu bar and choose **Open Dashboard**.
3. Complete onboarding. Optional permissions and background services may be skipped.
4. Choose **Install Demo Scene** or create a scene. Installation never activates the demo.
5. Review every action, dependency, condition, health check, URL, path, and process argument. Process arguments are exact array entries: empty, whitespace-only, tab, and multiline values remain distinct. Save only after validation succeeds.
6. Select **Activate**. Approve process actions only when the exact executable, arguments, directory, and environment references are expected.
7. Follow live state in **Current Run**. Cancel when needed; inspect degraded/failed actions and resources left running.
8. Use **Run History** to filter by scene, status, and local date; open a stored snapshot for full action details, current-preflight retry, scene-copy recovery, or redacted diagnostic export. Use **Deactivate** to stop resources owned by the scene where supported.

Scene data is local under `~/Library/Application Support/WorkspaceOrchestrator`. Imported files and captured workspaces always require review. Settings includes history retention, allow-listed transfer, explicit-scope reset, and Keychain reference labels that never reveal stored values. Optional hotkey, guided clap calibration/test, voice, spoken status, notifications, and launch-at-login controls are under Settings/Permissions.

If an action cannot start, first check **Integrations**, **Permissions**, and [Troubleshooting](TROUBLESHOOTING.md).
