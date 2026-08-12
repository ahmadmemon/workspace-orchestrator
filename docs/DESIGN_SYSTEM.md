# Design System

The visual direction is **Obsidian Command Center with Apple-native interaction**: dark graphite surfaces, restrained violet/cyan status light, generous hierarchy, and semantic state communicated with labels and symbols rather than color alone.

`ObsidianTokens` centralizes spacing, corner radii, semantic colors, and panel treatment. Workspace Core is the primary state visual; it is decorative support for text status, never the only status channel. Native SwiftUI controls, menus, focus, sheets, toolbars, and window behavior take precedence over custom interaction.

## Accessibility rules

- Every icon-only control requires a label/help string and keyboard path.
- State always includes readable text and a symbol; red/green alone is insufficient.
- Content remains usable with VoiceOver, keyboard-only navigation, increased contrast, Reduce Motion, and Reduce Transparency.
- Motion indicates state change but is suppressed/reduced when requested.
- Error content explains failure, impact, next action, and remaining resources.
- Activation audio/voice always has a non-audio global-shortcut/menu alternative.

The generated app-icon master is `docs/assets/AppIcon-master.png`; raster sizes and asset metadata live in the Xcode asset catalog. Human review at 1x/2x, light/dark desktop backgrounds, and all supported accessibility settings remains part of the smoke checklist.
