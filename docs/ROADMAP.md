# Roadmap

Work advances only after the current milestone is reviewed. Checked items describe verified repository implementation, not future intent.

## Milestone 1 — Foundation + First Working Scene

**Goal:** Establish the permanent native architecture and prove one complete, observable local scene workflow.

**Scope:** Scene schema and validation; three structured actions; native adapters; sequential execution, failure, timeout and cancellation; Application Support persistence; menu-bar UI; dashboard; scene CRUD/reordering; explicit demo installation; tests, CI, security model, and open-source foundations.

**Explicit non-scope:** Parallelism, dependencies, retries, health checks, restoration integrations, window control, gesture/voice activation, AI, cloud, accounts, signing, notarization, distribution, and updates.

**Acceptance criteria:** The modules respect their boundaries; untrusted scenes fail closed; tests do not open apps or browsers; process execution never uses shell strings; the app builds with Xcode; the demo is opt-in; errors and cancellation are visible; documentation matches reality.

**Checklist:**

- [x] Implement SceneCore, MacAutomation, and native SwiftUI app target
- [x] Implement validation, persistence, execution, cancellation, dashboard, and editor
- [x] Add 28 passing automated tests and macOS CI
- [x] Verify an unsigned Xcode development build
- [ ] Complete manual visual and interaction smoke testing
- [ ] Publish the GitHub repository after authentication

## Milestone 2 — Reliable Orchestration

**Goal:** Make longer and partially failing scenes predictable, recoverable, and safe to repeat.

**Scope:** Parallel actions; dependencies; retry strategies; HTTP, port, and process health checks; idempotency semantics; improved recovery and durable run history with privacy controls.

**Explicit non-scope:** Window layouts, workspace capture, ambient activation, cloud/team features, and release distribution.

**Acceptance criteria:** Execution graphs are deterministic; cycles and invalid dependencies fail validation; retries and timeouts are observable; health checks have bounded resource use; recovery behavior is tested; sensitive logs follow a redaction policy.

**Checklist:**

- [ ] Design versioned dependency and retry schemas
- [ ] Implement deterministic parallel scheduler and cancellation
- [ ] Add bounded HTTP, port, and process checks
- [ ] Define idempotency and recovery rules
- [ ] Add reliability, migration, and stress tests
- [ ] Complete security and manual review

## Milestone 3 — Workspace Restoration

**Goal:** Restore practical developer workspaces across applications, displays, projects, and services.

**Scope:** Window layouts; multi-display support; VS Code and terminal integrations; Docker Compose integration; browser workspace restoration; capture of the current workspace with review before saving.

**Explicit non-scope:** Clap/voice activation, AI scene creation, team synchronization, payments, and public release automation.

**Acceptance criteria:** Each integration is optional and inspectable; missing applications/displays degrade safely; capture never saves secrets silently; layouts handle display changes; integration failures are isolated and recoverable.

**Checklist:**

- [ ] Research narrow macOS permissions and APIs
- [ ] Define adapter/plugin boundaries
- [ ] Implement window and multi-display model
- [ ] Add VS Code, terminal, Docker Compose, and browser adapters
- [ ] Add reviewed workspace capture
- [ ] Test degraded and recovery paths

## Milestone 4 — Activation Experience

**Goal:** Let users activate a chosen scene quickly and receive a polished readiness experience.

**Scope:** Global shortcuts; double-clap detector; voice scene selection and activation phrase; readiness overlay; optional spoken status.

**Explicit non-scope:** Background surveillance, always-on cloud speech, implicit action execution without configured consent, commercial team administration, and distribution automation.

**Acceptance criteria:** Every activation mode is opt-in and can be disabled; microphone use is transparent and permission-scoped; false activations are bounded by confirmation policy; accessibility alternatives exist; overlay and spoken state match actual execution.

**Checklist:**

- [ ] Design consent and confirmation model
- [ ] Implement global shortcut activation
- [ ] Prototype local, privacy-preserving clap detection
- [ ] Add voice selection and activation phrase
- [ ] Build readiness overlay and spoken status
- [ ] Complete privacy, accessibility, and false-positive testing

## Milestone 5 — Open-Source Release Quality

**Goal:** Produce a trustworthy, repeatable public macOS release and contributor experience.

**Scope:** Developer ID signing; notarization; GitHub Releases; installation UX; update strategy; stable adapter/plugin architecture; release provenance and support policy.

**Explicit non-scope:** Team billing, organization policy, hosted synchronization, and managed integrations.

**Acceptance criteria:** Releases are signed and notarized from a documented process; checksums/provenance are published; installation and removal are clear; update behavior is consentful; plugin trust boundaries are documented; clean-machine testing passes.

**Checklist:**

- [ ] Establish signing and notarization process
- [ ] Add reproducible release workflow and provenance
- [ ] Design installation and removal UX
- [ ] Approve and implement update strategy
- [ ] Stabilize adapter/plugin interfaces
- [ ] Complete release candidate audit

## Milestone 6 — Commercial / Team Layer

**Goal:** Explore an optional organization layer without weakening the local-first individual product.

**Scope:** Encrypted synchronization; shared scenes; team templates; organization policies; managed integrations; collaboration and potential commercial packaging.

**Explicit non-scope:** Selling user telemetry, weakening end-to-end encryption, forcing accounts for local scenes, or remotely executing actions without local authorization.

**Acceptance criteria:** A reviewed business and threat model exists; local-only use remains first-class; synchronization is encrypted with clear key ownership; policies are explainable; administrators cannot silently obtain process output or secrets; collaboration has auditable consent.

**Checklist:**

- [ ] Validate user and organization needs
- [ ] Design identity, encryption, and key ownership
- [ ] Prototype opt-in synchronization and sharing
- [ ] Define policy and managed-integration boundaries
- [ ] Add collaboration auditability and recovery
- [ ] Complete independent privacy and security review
