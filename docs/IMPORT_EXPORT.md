# Import and Export

Scene export uses a versioned archive containing scene definitions and metadata. It excludes Keychain values, remembered process approvals, run history, and captured audio. Treat exported URLs, paths, arguments, environment names, and labels as potentially private.

Import decodes without side effects, rejects unsupported/invalid archives, migrates supported V1 scenes, and presents a review of duplicates, validation warnings, and risky process-bearing actions. Choose replace, create copy, or skip for duplicates. Imported trust is reset; saving an import does not activate it, and process execution still requires exact approval.

For portability, edit machine-specific paths, bundle IDs, display/window matches, Docker projects, and editor/terminal choices after import. Recreate missing Keychain references locally. A scene may validate structurally yet fail because an integration or selected file is unavailable on the destination Mac.

Do not import scenes from an untrusted author unless every action and policy is understood. Never add a secret directly just to make an exported file self-contained.

Historical scene snapshots are not scene archives and do not inherit trust. **Open Snapshot as New Scene** creates a reviewed editable copy. Historical retry performs current validation and approval/secret/integration preflight against the stored snapshot before offering execution.
