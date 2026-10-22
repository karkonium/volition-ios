# Volition — agent guide

Volition is a conversation-first iOS Screen Time app. The Xcode project and target
are still named OpenAppLock. Users save individual apps with a name and intention;
a respectful coach asks, denies, approves 1–10 minutes, or waits 1–5 minutes.
The product has only Chat, Apps and Settings. iPhone uses tabs; iPad uses a sidebar.

## Start here

- `Docs/Agents/Specs/CONVERSATION_UNLOCK.md`: current product/enforcement contract.
- `Docs/Agents/Specs/COMPATIBILITY.md`: why legacy models/services remain.
- `Docs/Agents/Specs/OPERATIONS.md`: permissions, logs, local config and copy.
- `Docs/Agents/Specs/BRANDING.md`: logo assets and generation prompt.
- `Docs/AGENT_SWIFT_GUIDELINES.md`: Swift, concurrency, testing and security rules.
- Behavior-owning source `///` comments are authoritative; update them with code.

## Architecture

| Location | Responsibility |
|---|---|
| `OpenAppLock/Models/` | SwiftData V1–V4 schemas, migrations, BlockingRule/AppList, ConversationArchive; legacy value models and regression tests remain |
| `OpenAppLock/Services/Conversation/` | Saved app setup/migration, shared chat/history, OpenAI client, diagnostics, approval support snapshots |
| `OpenAppLock/Views/Conversation/` | App library/editor, chat and coach settings |
| `OpenAppLock/Views/` | Root permission gate, onboarding, adaptive shell and diagnostic settings |
| `OpenAppLock/Services/RuleEnforcer.swift` | Foreground reconciliation, including a 30-second backstop |
| `OpenAppLock/Services/RuleScheduler.swift` | DeviceActivity registration and removal of retired monitors |
| `Shared/Stores/ConversationGrantStore.swift` | Coordinated App Group state, independent grants and pending shield target |
| `Shared/Enforcement/ConversationEnforcement.swift` | Transactional grant registration, shield release, expiry and rollback |
| `Shared/Enforcement/ShieldController.swift` | Per-rule ManagedSettings stores, orphan cleanup and configured-blocker readback |
| `Shared/` | Cross-process DTOs, domain logic, stores, diagnostics, copy and platform IDs |
| `OpenAppLockMonitor/` | Background expiry plus legacy activity callbacks |
| `OpenAppLockShieldConfig/`, `OpenAppLockShieldAction/` | Shield presentation and Request access → Chat routing |
| `OpenAppLockReport/` | Legacy usage-report extension; retained for compatibility |
| `OpenAppLockTests/`, `OpenAppLockUITests/` | Swift Testing domain suites and XCUITest flows |

## Invariants

- `VolitionApps.prepare` disables legacy rules before the shell appears. Preserve
  V1–V4 schemas and old callbacks; removing old screens does not remove old data.
- Each saved app has exactly one app token, a required name and intention. The
  picker closes on one valid app; cancelling preserves the previous selection.
- Chat and app selection remain available during timers. Grants/waits are per
  app. Ending one grant must not change another app’s original deadline.
- The coach receives cross-app access history, active grants and the selected
  app’s wait. A local wait prevents early approval but does not disable chat.
- Approval requires a registered timer, durable state, matching configuration and
  no configured blocker. Failed activation must not publish a success response.
- All grant mutations and shield writes use the coordinated App Group transaction.
  Stale expiry callbacks must never end a replacement or another app’s grant.
- iOS 26.5+ releases clear/deactivate/delete the dedicated rule store; future blocks
  recreate it. Enumerate actual stores as well as defaults to find orphaned rules.
- Configured readback does not prove the OS has dismissed a shield. Real-device
  acceptance matters. Maps/SoundCloud opening and the native picker are verified;
  long-run repetition and background/terminated short expiry need observation.
- Background grants use a 16-minute DeviceActivity interval and an end warning at
  the 1–10-minute deadline. OS callbacks may be late; do not promise exact expiry.
- Never remove compatibility schemas, enforcement or extension targets as a
  cosmetic cleanup. Shared files compile into the app and four extensions.

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
- UI launches use `-ui-testing`, mocked authorization/shields and in-memory storage;
  `-onboarding-completed`/`-onboarding-required` and `-seed-scenario=conversation` or
  `conversation-multiple` make flows deterministic. `-seed-logs` seeds diagnostics.
- Stable IDs include `conversationMessageField`, `conversationSendButton`,
  `conversationChooseAppButton`, `conversationAppOption`, `conversationCooldown`,
  `endConversationUnlockButton`, `addVolitionAppButton`, `pickVolitionAppButton`,
  `volitionAppName`, `volitionAppNameHelp`, `volitionAppIntention`,
  `saveVolitionAppButton`, `finishVolitionSetupButton`, and `sidebarItem-chat/apps/settings`.

## Credentials

`OpenAppLock/Conversation.env` is a personal ignored file bundled for this prototype;
`Config/Conversation.env.example` is the tracked placeholder. Never print/copy real
keys into docs, logs, tests or commits. Never distribute a personal-key build.
Check that a device build still bundles the local config without printing it.
Old local archival branches may contain keys: never push historical branches
blindly. Do not bypass GitHub secret protection; preserve remote history and
sanitize unpublished work before pushing.
