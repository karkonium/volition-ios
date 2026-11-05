# Volition — agent guide

Volition is a conversation-first Expo React Native iOS Screen Time app.
`App.tsx` starts the shipping app; its generated workspace and scheme are `Volition`.
Expo prebuild owns the generated `ios/Volition.xcworkspace`; the retired native
project, compatibility harness and native test folders were removed at the user’s request. Users save individual apps with a name and intention;
a respectful coach asks for intention, approves 1–60 minutes, offers reflections
or explicit access/break deals, and progressively challenges rapid repeat use.
Ten-second delays start immediately; longer delays require explicit agreement.
Elapsed/ended delays require an explicit Unlock or Keep locked choice; emotions never gate access.
Suggested pauses progress per app from 10 to 60 seconds over 24 hours; each recent
broken deal adds 60 seconds, capped at 1,800. Longer delays require agreement.
App removal asks why, offers a normal temporary-access request, and records private
high-frustration feedback. Users always control removal.
Legacy enforced waits remain readable and cannot be bypassed.
The product has Chat, Apps, Insights, Focus and Settings. iPhone uses tabs; iPad uses a sidebar.
Minimum deployment target: iOS 18. Runtime checks currently use iOS 27; the iOS
18.5 simulator was unavailable from Xcode's download catalog. Older-device
enforcement and notification acceptance remain pending.

## Start here

- `Docs/Agents/Specs/EXPO_MIGRATION.md`: current source ownership, bridge and build workflow.

- `Docs/Agents/Specs/CONVERSATION_UNLOCK.md`: current product/enforcement contract.
- `Docs/Agents/Specs/COMPATIBILITY.md`: why legacy models/services remain.
- `Docs/Agents/Specs/OPERATIONS.md`: permissions, logs, local config and copy.
- `Docs/Agents/Specs/BRANDING.md`: logo assets and provenance.
- `Docs/AGENT_SWIFT_GUIDELINES.md`: Swift, concurrency, testing and security rules.
- Behavior-owning source `///` comments are authoritative; update them with code.

## Architecture

| Location | Responsibility |
|---|---|
| `App.tsx`, `src/navigation/`, `src/screens/` | Provider tree, permissions/onboarding, five tabs and iPad sidebar |
| `src/layout/`, `src/components/` | Ahhzo Elements 0.8.2 theme, semantic type, adaptive colors and 44-point actions |
| `src/redux/` | Persisted profiles, consent, chat, offers, grants, Focus and private outcomes |
| `src/services/` | Coach client/policy, routing, local validation, native reconciliation and exports |
| `modules/volition-screen-time/ios/` | Expo bridge, native picker/icon, Keychain and legacy import |
| `modules/volition-screen-time/ios/LegacyModels/` | Frozen SwiftData V1–V5 schemas and migrations |
| `modules/volition-screen-time/ios/Shared/` | Authoritative cross-process stores, enforcement, Focus, diagnostics, copy and platform IDs |
| `modules/volition-screen-time/ios/ActivityShared/` | ActivityKit attributes |
| `targets/shield-config/`, `targets/shield-action/` | Shield presentation and lightweight Request access routing |
| `targets/activity-monitor/`, `targets/activity-report/`, `targets/live-activity/` | Background expiry, compatibility callbacks/report and native countdown |
| `Scripts/link-native-sources.py`, `Scripts/patch-expo-headers.cjs` | Source-link maintenance and reproducible SDK header corrections |

Paths to `OpenAppLock/Views`, top-level `Shared` and old extension folders in older
spec sections describe the pre-migration layout; use the ownership table above.
The superseded SwiftUI interface has been removed. The user explicitly requested removal of the retired compatibility host and
native test suites. New regression coverage belongs to the Expo test setup.

## Invariants

- `VolitionApps.prepare` disables legacy rules before the shell appears. Preserve
  V1–V5 schemas and old callbacks; removing old screens does not remove old data.
- Each saved app has exactly one app token, a required name and intention.
  Optional structured purposes/changes/session style live in ConversationArchive,
  keyed by rule ID; optional notes retain old free text and get a neutral default
  when skipped. Do not modify frozen SwiftData schemas for profile fields. The
  picker closes on one valid app; cancelling preserves the previous selection.
  Missing-name Save attempts focus/highlight the name using the shared attention effect.
- The coach asks for a current intention (boredom is valid) and progressively
  follows intention → short pause/optional trigger check-in → negotiated deal →
  last-resort refusal. Counts alone never justify skipping earlier interventions;
  declining a voluntary pause/deal is not disobedience.
  CoachingPolicy owns the progressive prompt. AI sharing defaults on only when
  unset; saved opt-outs remain off and onboarding retains its disclosure/choice.
  AI consent gates every transmission;
  withdrawing consent cancels pending responses/reflections. GPT-5.4 mini uses medium decision reasoning. Counts describe allocated unlock
  sessions (short 1–5, longer 6–60 minutes), never measured foreground usage.
- Pauses/delays are BEFORE access; deals are access THEN a block. Ask users to
  reflect on a suggested short pause first; longer pause lengths (10–1,800
  seconds) and deal terms are chosen willingly. After two recent started pause
  attempts prefer a deal or Delay, Deal or Open choice; a completed pause is not a hard
  prerequisite. Choice offers exactly Delay/Deal/quieter Open actions, bound to
  the same access duration. Open neither creates a deal nor counts as a pause.
  Sample optional independent check-ins for half of intervention
  requests, with a persisted global 120-second question cooldown. Custom emotions
  are limited to 160 trimmed characters; the legacy Other value remains readable.
  Check-ins are shared by delays/deals/choices. Practical work requests avoid rituals.
- Deal offers require Accept/Decline. Accepted 1–60-minute grants atomically store
  a 1–1,440-minute break until original expiry plus break, retained after early end,
  relaunch and Clear Chat. Overrides require two prior actual coach pushbacks and explicit acceptance
  of a replacement deal with a longer break (remaining minutes + 15, minimum 30,
  maximum 1,440). Repeated overrides are possible; rollback restores old terms. Keep the
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
  Active unlocks use compact pinned banners outside the transcript. Soft delays
  have an inline seconds countdown and small End delay action. Expiry/end never
  opens automatically: show a quieter Unlock and bright Keep locked. Emotion
  check-ins appear alone first; answering or Skip reveals the separate intervention
  message and starts a ten-second delay only then. Neither accepts a deal or unlocks.
  It persists a deadline and planned unlock, claims activation
  durably once, and uses the same grant checks without another model request.
  Foreground lifecycle expires offers but never automatically activates them;
  only explicit Unlock/Accept actions may grant. Never grant in background.
  Recovered activating claims are interrupted, not replayed. Long offers require
  Start; new model wait responses are voluntary offers, not fresh hard cooldowns.
  Emotion context is limited to ten records in 24 hours, outside chat summaries.
- Confirmed unlock/keep-locked outcomes offer private Helpful/Neutral/Annoying
  feedback. Ratings never control access and export with the activity log.
- Valid foreground shield requests leave saved-app setup for Chat even before
  Start chatting; unfinished app editor drafts are not saved.
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
  interval and an end warning at the 1–60-minute deadline. OS callbacks may be late; do not promise exact expiry.
- Never remove compatibility schemas, enforcement or extension targets as a
  cosmetic cleanup. Shared files compile into the app and the original four extensions; ActivityShared compiles into the app, monitor and Live Activity widget.

## Build and test

Run `npm run typecheck`, `npm test`, and `npx expo prebuild --clean`. Build the
generated workspace with:

```sh
xcodebuild -workspace ios/Volition.xcworkspace -scheme Volition \
  -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

The local module enables complete concurrency checking and Swift warnings as
errors in its podspec. Native dependencies retain their upstream diagnostics.
`npm ci` applies the checked-in SDK header corrections and shared-source links.
Never register source files manually in the generated project; update module,
target or plugin configuration so clean prebuild reproduces the change.

For simulator UI verification, first query `xcrun simctl list devices booted` and
use a fresh/unbooted simulator or one owned by this task. Never collide with
somebody else’s booted simulator. Real FamilyControls selections, visible shields,
background expiry and notification/Live Activity acceptance need a physical phone.
Report pending device verification explicitly. The explicit development preview
uses `EXPO_PUBLIC_VOLITION_PREVIEW=1`, synthetic selections and mock coaching;
it cannot prove real enforcement and is disabled in production builds.

## Workflow and documentation

- Plan nontrivial work and confirm scope before editing; existing user authorization
  counts. Consult the owning feature contract before behavior changes.
- Use red-green TDD: failing test first (compile failure counts), implement, focused
  tests, then the full suite. Keep Expo regression coverage; the user explicitly removed the retired native test suites.
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

- SwiftData: insert both models before wiring relationships; repeated containers
  can trap inside SwiftData. Keep persisted V1–V5 fields unchanged.
- App target defaults to MainActor isolation. Shared cross-process values must be
  Sendable/nonisolated; import the defining FamilyControls module for token APIs.
- SwiftUI container identifiers need `.accessibilityElement(children: .combine)`
  or a control to be queryable. Section headers need `.textCase(nil)` for exact copy.
- Use concrete `Color.primary/secondary` inside tinted button rows.
- iPad sheets are shorter and centered; scroll controls into view and navigate via
  idiom-aware helpers, not hardcoded tab bars or full-window edge swipes.
- Unsigned builds cannot prove ManagedSettings registration or visible shield release.
- If XCTest waits 60 seconds for keyboard animations and a short test grant expires,
  rerun the timer flow in isolation. This occurred during concurrent iPhone/iPad
  automation; do not change production deadlines to accommodate the test runner.
- Expo development previews require the explicit preview environment flag; they
  never authorize real access. No retired SwiftUI launch-argument harness remains.
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

Expo stores user-entered OpenAI keys in native Keychain; never persist them in Redux,
App Group state or technical logs. No personal-key file is bundled in the Expo application. Never print/copy real
keys into docs, logs, tests or commits. Never distribute a personal-key build.
Verify production builds do not bundle personal configuration.
Old local archival branches may contain keys: never push historical branches
blindly. Do not bypass GitHub secret protection; preserve remote history and
sanitize unpublished work before pushing.
