# Quick Start

1. Build and run `WorkspaceOrchestratorApp` from Xcode on macOS 14+, or install a signed/notarized release when one is published.
2. Open the grid item in the menu bar and choose **Open Dashboard**.
3. Complete onboarding. Optional permissions and background services may be skipped.
4. Choose **Install Demo Scene** or create a scene. Installation never activates the demo.
5. Review every action, dependency, URL, path, and process argument. Save only after validation succeeds.
6. Select **Activate**. Approve process actions only when the exact executable, arguments, directory, and environment references are expected.
7. Follow live state in **Current Run**. Cancel when needed; inspect degraded/failed actions and resources left running.
8. Use **Run History** for prior outcomes and **Deactivate** to stop resources owned by the scene where supported.

Scene data is local under `~/Library/Application Support/WorkspaceOrchestrator`. Imported files and captured workspaces always require review. Optional hotkey, clap, voice, spoken status, notifications, and launch-at-login controls are under Settings/Permissions.

If an action cannot start, first check **Integrations**, **Permissions**, and [Troubleshooting](TROUBLESHOOTING.md).
