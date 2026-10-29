# Volition — agent guide

Volition is a conversation-first iOS Screen Time app. The Xcode project and target
are still named OpenAppLock. Users save individual apps with a name and intention;
a respectful coach asks for intention, approves 1–30 minutes, offers reflections
or explicit access/break deals, and progressively challenges rapid repeat use.
Ten-second reflections are skippable; longer pauses require explicit agreement.
Suggested short pauses progress per app from 10 to 60 seconds over 24 hours.
App removal asks why, offers a normal temporary-access request, and records private
high-frustration feedback. Users always control removal.
Legacy enforced waits remain readable and cannot be bypassed.
The product has Chat, Apps, Insights, Focus and Settings. iPhone uses tabs; iPad uses a sidebar.
Minimum deployment target: iOS 18. Runtime checks currently use iOS 27; the iOS
18.5 simulator was unavailable from Xcode's download catalog. Older-device
enforcement and notification acceptance remain pending.

## Start here

- `Docs/Agents/Specs/CONVERSATION_UNLOCK.md`: current product/enforcement contract.
- `Docs/Agents/Specs/COMPATIBILITY.md`: why legacy models/services remain.
- `Docs/Agents/Specs/OPERATIONS.md`: permissions, logs, local config and copy.
- `Docs/Agents/Specs/BRANDING.md`: logo assets and provenance.
- `Docs/AGENT_SWIFT_GUIDELINES.md`: Swift, concurrency, testing and security rules.
- Behavior-owning source `///` comments are authoritative; update them with code.

## Architecture

| Location | Responsibility |
|---|---|
| `OpenAppLock/Models/` | SwiftData V1–V5 schemas, migrations, BlockingRule/AppList, ConversationArchive/ConversationRecord; legacy value models and regression tests remain |
| `OpenAppLock/Services/Conversation/` | Saved app setup/migration, name routing, shared chat/history, private activity log/exports, OpenAI client, diagnostics, approval support snapshots |
| `OpenAppLock/Views/Design/` | Compact native card, button, section and form styles; preserve semantic type, adaptive colors and 44-point actions |
| `OpenAppLock/Views/Conversation/` | App library/editor, chat, activity log and coach settings |
| `OpenAppLock/Views/` | Root permission gate, onboarding, adaptive shell and diagnostic settings |
| `OpenAppLock/Services/FocusController.swift`, `Shared/Focus/` | Focus sessions/schedules and stricter local protection |
| `OpenAppLock/Services/RuleEnforcer.swift` | Foreground reconciliation, including a 30-second backstop |
| `OpenAppLock/Services/RuleScheduler.swift` | DeviceActivity registration and removal of retired monitors |
| `Shared/Stores/ConversationGrantStore.swift` | Coordinated App Group state, independent grants and pending shield target |
| `Shared/Stores/ConversationRequestStore.swift` | Fresh notification/manual request identities and acknowledgements; advisory metadata without grant-file locks |
| `Shared/Enforcement/ConversationEnforcement.swift` | Transactional grant registration, shield release, expiry and rollback |
| `Shared/Enforcement/ShieldController.swift` | Per-rule ManagedSettings stores, orphan cleanup and configured-blocker readback |
| `Shared/` | Cross-process DTOs, domain logic, stores, diagnostics, copy and platform IDs |
| `OpenAppLockMonitor/` | Background expiry plus legacy activity callbacks |
| `OpenAppLockShieldConfig/`, `OpenAppLockShieldAction/` | Shield presentation and Request access → Chat routing |
| `ActivityShared/`, `VolitionLiveActivity/` | Shared ActivityKit attributes; native Lock Screen/Dynamic Island countdown |
| `OpenAppLockReport/` | Legacy usage-report extension; retained for compatibility |
| `OpenAppLockTests/`, `OpenAppLockUITests/` | Swift Testing domain suites and XCUITest flows |

## Invariants

- `VolitionApps.prepare` disables legacy rules before the shell appears. Preserve
  V1–V5 schemas and old callbacks; removing old screens does not remove old data.
- Each saved app has exactly one app token, a required name and intention.
  Optional structured purposes/changes/session style live in ConversationArchive,
  keyed by rule ID; optional notes retain old free text and get a neutral default
  when skipped. Do not modify frozen SwiftData schemas for profile fields. The
  picker closes on one valid app; cancelling preserves the previous selection.
- The coach asks for a current intention (boredom is valid) and progressively
  follows intention → short pause/optional trigger check-in → negotiated deal →
  last-resort refusal. Counts alone never justify skipping earlier interventions;
  declining a voluntary pause/deal is not disobedience.
  CoachingPolicy owns the progressive prompt. AI consent gates every transmission;
  withdrawing consent cancels pending responses/reflections. GPT-5.4 mini uses medium decision reasoning. Counts describe allocated unlock
  sessions (short 1–5, longer 6–30 minutes), never measured foreground usage.
- Pauses/delays are BEFORE access; deals are access THEN a block. Ask users to
  reflect on a suggested short pause first; longer pause lengths (10–1,800
  seconds) and deal terms are chosen willingly. A completed, unskipped
  pause for that app within 24 hours is required before offering a deal.
- Deal offers require Accept/Decline. Accepted 1–30-minute grants atomically store
  a 1–1,440-minute break until original expiry plus break, retained after early end,
  relaunch and Clear Chat. Rare overrides require two prior actual coach
  pushbacks and cannot break two resolved deals consecutively across apps. A
  fulfilled deal resets eligibility; rollback restores overridden terms. Keep the
  shared commitment ledger after expiry; do not prune exception history.
- Grant presentation follows per-app configuration validity, including after
  unrelated app edits. Focus revocations remove only affected reminders/cards.
  Grant presentation: one ActivityKit countdown per published grant plus grouped
  local reminders at 60/30/10 seconds remaining. Native rendering/delivery is
  best-effort and never controls enforcement. Cancel only the ended grant's
  reminders/activity; late async work must not revive a completed activity.
- Chat and app selection remain available during timers. Grants/waits are per
  app. Ending one grant must not change another app’s original deadline.
- The coach receives cross-app access history, active grants and the selected
  app’s wait. A local wait prevents early approval but does not disable chat.
  Only unlocks show top timers; a declined request has no waiting countdown.
  Soft reflection has its own inline seconds countdown, optional emotion choice,
  skip and cancel. Keep unanswered choices visible after the pause; normal
  completion needs a choice (including Not sure / Skip) and elapsed time.
  It persists a deadline and planned unlock, claims activation
  durably once, and uses the same grant checks without another model request.
  Service it from the foreground shell even outside Chat; never grant in background.
  Recovered activating claims are interrupted, not replayed. Long offers require
  Start; new model wait responses are voluntary offers, not fresh hard cooldowns.
  Emotion context is limited to ten records in 24 hours, outside chat summaries.
- Saved app names can route messages before sending. Ambiguous/missing targets
  preserve the draft and highlight the picker; explicit selection resolves them.
- The private activity log records content and actual local outcomes separately
  from model decisions. Failed activation must never be logged as unlocked.
  Clear Chat retains this log; clearing it retains coaching/enforcement history.
- Approval requires a registered timer, durable state, matching configuration and
  no configured blocker. Failed activation must not publish a success response.
- All grant mutations and shield writes use the coordinated App Group transaction.
  Stale expiry callbacks must never end a replacement or another app’s grant.
- Shield requests open Volition directly on iOS 26.5+ and use notification/manual
  routing below that version. The earlier direct path had reported system UI hangs;
  preserve the lightweight request store. Repeated direct opening, correct selection
  and Home navigation are user-verified with this implementation.
  Callback completion is bounded and once-only; shield request/render paths never
  acquire the grant file lock. Foreground routing consumes lightweight requests;
  background reconciliation must leave them pending.
- iOS 26.5+ releases clear/deactivate/delete the dedicated rule store; future blocks
  recreate it. Enumerate actual stores as well as defaults to find orphaned rules.
- Configured readback does not prove the OS has dismissed a shield. Real-device
  acceptance matters. Maps/SoundCloud, the native picker and repeated notification
  requests with working Home navigation are verified on the connected iPhone;
  long-run repetition and background/terminated short expiry need observation.
- Background grants use a max(16, requested minutes + 5)-minute DeviceActivity
  interval and an end warning at the 1–30-minute deadline. OS callbacks may be late; do not promise exact expiry.
- Never remove compatibility schemas, enforcement or extension targets as a
  cosmetic cleanup. Shared files compile into the app and the original four extensions; ActivityShared compiles into the app, monitor and Live Activity widget.

## Build and test

Prefer connected Xcode MCP build/test tools. If unavailable, use `xcodebuild`.
Scheme: `OpenAppLock`; project: `OpenAppLock.xcodeproj`.

1. Query `xcrun simctl list devices booted`. Use a fresh/unbooted simulator or one
   owned by this task; never collide with somebody else’s booted simulator.
2. Run tests against an iOS simulator, never a physical-device test destination:

   ```sh
   xcodebuild test -project OpenAppLock.xcodeproj -scheme OpenAppLock \
     -destination 'platform=iOS Simulator,id=<owned-UDID>' \
     -only-testing:OpenAppLockTests/<Suite>
   ```

3. Drop the filter for the full suite. CLI runs are headless; do not open Simulator
   just to test. Build a signed device artifact with `-destination 'generic/platform=iOS'`.
4. Screenshots: use Xcode previews/device tools when present; otherwise drive
   XCUITest, export xcresult attachments and inspect the images yourself.
5. FamilyControls compiles on the simulator, but actual shields/background callbacks
   need a phone. The UI harness mocks picker selections; real selection needs real
   authorization. Report any pending device verification explicitly.

The project uses file-system-synchronized groups: add/remove Swift files on disk;
no manual pbxproj source registration is needed.

## Workflow and documentation

- Plan nontrivial work and confirm scope before editing; existing user authorization
  counts. Consult the owning feature contract before behavior changes.
- Use red-green TDD: failing test first (compile failure counts), implement, focused
  tests, then the full suite. Keep all compatibility regression coverage.
- Attempt visual UI verification before committing rendered changes. If preview/
  interaction tooling is unavailable, explicitly report the limitation and hand
  real-device acceptance to the user; do not silently claim verification.
- Use a topic branch and a GitHub PR for maintainer review. Follow an explicit user
  instruction to merge; otherwise leave main changes to reviewed PRs.
- Commit only when requested. Use conventional commits and a specific agent/model
  `Co-Authored-By:` trailer (for example `Codex (GPT-6) <noreply@openai.com>`).
- Agent-managed docs: this file, CLAUDE.md, `AGENT_*` files and everything under
  `Docs/Agents/`. Maintain a compact current guide; completed plans live in Git.
- Other docs are human-authored: read them, but do not create/change them without
  explicit user authorization. Preserve README/license/project metadata in cleanup.

## Test and platform gotchas

- SwiftData: insert both models before wiring relationships. Tests use the shared
  `makeInMemoryContext()` factory; repeated containers can trap inside SwiftData.
- App target defaults to MainActor isolation. Shared cross-process values must be
  Sendable/nonisolated; import the defining FamilyControls module for token APIs.
- SwiftUI container identifiers need `.accessibilityElement(children: .combine)`
  or a control to be queryable. Section headers need `.textCase(nil)` for exact copy.
- Use concrete `Color.primary/secondary` inside tinted button rows.
- iPad sheets are shorter and centered; scroll controls into view and navigate via
  idiom-aware helpers, not hardcoded tab bars or full-window edge swipes.
- Unsigned CI cannot register ManagedSettings stores. Config/CI.xcconfig marks
  the native store-release integration test unavailable; signed local runs retain
  it. Domain/enforcement regressions still run in CI. Export UI tests use the
  exported filename, not Apple’s private labels/hierarchy.
- If XCTest waits 60 seconds for keyboard animations and a short test grant expires,
  rerun the timer flow in isolation. This occurred during concurrent iPhone/iPad
  automation; do not change production deadlines to accommodate the test runner.
- UI launches use `-ui-testing`, mocked authorization/shields and in-memory storage;
  `-onboarding-completed`/`-onboarding-required` and `-seed-scenario=conversation` or
  `conversation-multiple` make flows deterministic. `-seed-logs` seeds diagnostics.
- Stable IDs include `conversationMessageField`, `conversationSendButton`,
  `conversationChooseAppButton`, `conversationAppOption`, `conversationAppSelectionHint`,
  `conversationActivityLogButton`, `exportActivityLogButton`, `clearActivityLogButton`,
  `endConversationUnlockButton`, `addVolitionAppButton`, `pickVolitionAppButton`,
  `volitionAppName`, `volitionAppNameHelp`, `volitionAppIntention`,
  `saveVolitionAppButton`, `finishVolitionSetupButton`, `profilePurposes`,
  `profilePurpose-<value>`, `conversationTranscript`, `conversationJumpLatest`,
  `reflectionCountdown`, `reflectionEmotion-<value>`, `skipReflectionButton`,
  `startReflectionButton`, `cancelReflectionButton`, and `sidebarItem-chat/apps/settings`.

## Credentials

`OpenAppLock/Conversation.env` is a personal ignored file bundled for this prototype;
`Config/Conversation.env.example` is the tracked placeholder. Never print/copy real
keys into docs, logs, tests or commits. Never distribute a personal-key build.
Check that a device build still bundles the local config without printing it.
Old local archival branches may contain keys: never push historical branches
blindly. Do not bypass GitHub secret protection; preserve remote history and
sanitize unpublished work before pushing.
