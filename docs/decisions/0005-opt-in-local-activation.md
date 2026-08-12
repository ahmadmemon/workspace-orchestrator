# ADR 0005: Opt-in local activation

- Status: Accepted
- Date: 2026-08-12

## Context

Global shortcuts, clap detection, and voice commands are useful ambient entry points but create input-observation, microphone, false-activation, privacy, accessibility, and energy risks.

## Decision

ActivationKit is separate from orchestration and disabled by default. The global shortcut uses the Carbon hot-key API and observes only the registered chord. Clap detection uses transient duration, energy relative to an adaptive noise floor, high-frequency content, spectral flatness, timing, and cooldown; it never records, stores, transcribes, or uploads audio. Its default result is a scene picker.

Voice mode begins only through an explicit user action, requires microphone and Speech authorization, sets `requiresOnDeviceRecognition`, and fails visibly when on-device recognition is unavailable. It never silently uses cloud recognition. Parsing and scene matching are deterministic; fuzzy and ambiguous matches require visible confirmation. Spoken status is optional, state-derived, excludes raw output/paths/secrets, and remains silent while VoiceOver is enabled.

## Consequences

The core application remains fully usable without microphone, Speech, or Accessibility permission. Automated tests operate on feature frames and text, not live input. Human acceptance must still cover permission prompts, menu-bar listening indication, audio-device interruption, energy behavior, false positives, locale support, keyboard alternatives, and VoiceOver interaction.
