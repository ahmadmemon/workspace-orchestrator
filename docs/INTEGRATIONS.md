# Integrations

Integrations are optional local adapters. Discovery reports actual installed executable/application status; unavailable tools never appear as connected.

| Integration | Scene behavior | Discovery / safety |
| --- | --- | --- |
| Applications | Open by bundle identifier | `NSWorkspace`; missing bundle fails visibly |
| Browser URLs | Open explicit HTTP(S) URL | System browser; no browser scripting |
| Files/Folders | Open or reveal a selected path | Explicit path/bookmark; configurable missing-path policy |
| VS Code family | Open folder/workspace and optional file locations | Known `code`, Insiders, Cursor, or VSCodium CLI; structured args |
| Terminal/iTerm | Open a directory/profile or tmux session | Typed request; no user-provided shell wrapper |
| Docker Compose | `up` selected services and health-check them; stop/down on deactivation | Known Docker CLI; project-scoped ownership; destructive flags rejected |
| macOS Shortcuts | Run a named installed Shortcut | `/usr/bin/shortcuts` with structured args; explicit name/input |
| Window layout | Match and place reviewed windows | Requires Accessibility; normalized multi-display fallback |

Use the Integrations screen to inspect discovered status and guidance. A green/available state means the executable or application was found, not that credentials, a project, or every command is valid. Run a harmless reviewed scene to validate an end-to-end integration.

Missing tools, missing files, invalid Docker projects, unhealthy services, and inaccessible windows produce typed errors or warnings according to action policy. Workspace Orchestrator does not install tools or alter their credentials.
