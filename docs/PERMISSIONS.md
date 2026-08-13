# Permissions

Workspace Orchestrator works without optional permissions for ordinary application, URL, file, and approved process actions.

| Permission/service | Used for | When requested | If denied |
| --- | --- | --- | --- |
| Accessibility | Enumerating/moving reviewed windows | Capture/window layout feature | Window features are unavailable; other actions continue |
| Microphone | Local double-clap feature extraction, guided calibration, and nonexecuting test; raw audio is never stored | User enables, calibrates, or tests double-clap | Clap service remains paused; no retry occurs until permission is granted and the user resumes |
| Speech Recognition | On-device voice commands | User enables voice | Voice service remains off; no cloud fallback |
| Notifications | Optional run completion/failure alerts | User enables notifications | In-app status remains available |
| Launch at Login | Starting the menu-bar app after login | User enables it | Manual launch remains available |

The app does not require administrator access, camera, screen recording, input monitoring, or Full Disk Access. The global shortcut uses Carbon registration, not key logging. Permission status can be reviewed in the Permissions screen and relevant System Settings pages can be opened explicitly.

Disabling a feature stops its service. Revoking a system permission may require relaunching or retrying the feature before status refreshes. Window capture and audio/voice behavior require human verification on real hardware before stable release.
