# Runtime operations

## Permissions and startup

RootView derives launch/onboarding/access-required/main destinations from current
Screen Time authorization. Foreground entry refreshes authorization; a revoked
permission must show the full access-required gate before MainView’s enforcement
loop runs. See RootDestination, ScreenTimeAuthorization, RootView and
ScreenTimeAccessRequiredView. UI tests use mocked providers.

After authorization, MainView prepares legacy data, reconciles shields/monitoring,
and requires at least one saved app. It refreshes on app changes, foreground entry
and a 30-second loop. Foreground requests return to Chat; notification links bind
to their saved profile ID rather than a newer global target. Background refreshes
do not consume requests. UI navigation state is not a persisted rule schema.

Each Request access tap records fresh, five-minute routing metadata in App Group
preferences. On iOS 26.5+ the handler immediately returns openParentalControlsApp;
no notification APIs or permission prompts are needed. Below iOS 26.5 it schedules
a unique “Chat here” notification and defers/redraws the shield with notification,
permission and manual-opening instructions. Older-OS notification permission is
requested from the main flow, never the extension. Coach settings offers its
notification shortcut on every OS because unlock reminders also need permission. Delivery is best-effort and cannot grant
access. Both routes retain manual opening. Metadata logs identify the chosen route
and response timing, plus notification scheduled/unavailable events when relevant.
The action callback completes once, with a one-second fallback. The request/render
path must never take the grant-state file coordinator lock. Earlier direct-opening
hangs have an unproven cause. The user verified repeated direct requests select
the correct app and Home works with this restoration; long-running observation
and older-device verification remain pending.

## Personal OpenAI configuration

Copy `Config/Conversation.env.example` to ignored `OpenAppLock/Conversation.env`.
Set OPENAI_API_KEY locally; the client currently uses gpt-5.4-mini (medium decision reasoning; low summary reasoning). Rebuild/reinstall
when changing the file. Confirm the built app contains the local config without
printing its contents. This is a personal prototype; do not distribute its key.

CONVO_LOG_ENABLED=0 disables temporary conversation tracing. Tagged logs distinguish
key loading, request start/status/validation, model decisions, timer registration,
configured blocker counts and precise local rejection categories. Never log raw
API errors, chat, intentions, tokens or keys; server errors can echo a credential.

## Diagnostics

Settings → Activity Log is the private, user-readable request history, separate
from technical diagnostics. It stores timestamps, app IDs/names, user messages,
coach replies, model decisions and actual local outcomes inside ConversationArchive.
Readable text and ISO-8601 JSONL exports are explicit user actions. Clearing the
log removes its entries/generated local exports, but retains coaching access
history and waits. Clear Chat retains the log. Old access events migrate once;
approvals without a recorded grant are unconfirmed. Pending requests recovered
after relaunch are interrupted, never assumed unlocked. Do not include this
content log in automatic support snapshots or os.Logger/App Group diagnostics.

`Diag` writes to os.Logger and per-process daily App Group files. Separate app,
monitor, shield and report writers prevent concurrent appends to the same file.
Each event includes its originating source location. LogStore merges/export days
from Settings → Diagnostics → Logs. Retention/merge behavior is tested under
Shared/Diagnostics; diagnostics must never change enforcement decisions.

Debug builds preserve the latest real approval attempt in
Documents/VolitionSupport/LatestApproval. It contains enforcement state, configured
store metadata, a timestamp and controlled logs, but no transcript/SwiftData/key.
Use Apple’s normal app-data transfer tool to retrieve it without restarting the
app. A missing source file must remove a stale exported state file. The explicit
`-export-conversation-support` launch flag also exports support data at startup.
Configuration metadata is not proof of the OS-visible shield state.

## Copy

Shared/Copy/CopyKey.swift indexes user-facing text in Shared/Copy.xcstrings.
The dedicated Copy table is embedded in every process; SwiftUI uses `.resource`
and non-UI producers use `.string`/formatted variants. Keep smart typography.
Unused keys from removed screens may be pruned only after checking Swift references;
CopyCatalogTests verify every retained key resolves and has valid typography.

## Verification limits

FamilyActivityPicker’s real selection needs FamilyControls authorization. The UI
harness exercises a synthetic selection through the same draft/validation path;
the user has separately verified native single-app auto-dismiss and name guidance.
Real blocking and DeviceActivity timing cannot be established in the simulator.
Foreground SoundCloud/Maps unlocks are user-verified. Long-running use and grant
expiry while backgrounded or terminated still require device observation.

Unsigned CI explicitly skips the native ManagedSettings store-release integration
test because ManagedSettingsAgent rejects store creation without a signed host.
Signed local runs retain it; deterministic enforcement tests still run in CI.
The activity export menu must dismiss normally before the share sheet appears;
do not disable the menu from inside its own export action. Its UI test uses
the exported filename rather than OS-specific Close labels/private preview IDs.

## Access reminders and Live Activities

Notifications are offered on all supported iOS versions; Settings → Coach Settings
links to notification permissions. They are separate from direct shield routing.
One Live Activity per confirmed grant uses a native date countdown. Three local
reminders share a grant-specific thread but keep distinct pending identifiers;
using the same pending identifier would replace earlier warnings. No server or
push credentials are required. Focus, permissions and OS delivery rules can hide
or delay alerts. ActivityKit failure never prevents access. Foreground recovery
removes stale presentation; monitor callbacks attempt activity cleanup at expiry.
The opt-in `-ui-testing-live-activity` test schedules real native presentation on
the owned simulator with mocked enforcement; ordinary UI tests remain hermetic.

## Compiler diagnostics

Shared.xcconfig enables complete concurrency checking while retaining Swift 5
language mode. InferSendableFromCaptures is enabled so immutable closure/key-path
literals satisfy the newer SDK's Sendable requirements. UI automation runs on
MainActor; migration helpers run synchronously on SwiftData's callback executor.
Schema version metadata is immutable; V1–V5 persisted fields are unchanged.
Diagnostic timestamps keep their existing millisecond rounding under a mutex.
SDK tokens cross detached-task boundaries as encoded Data, and async Live Activity
cleanup passes activity IDs rather than non-Sendable handles across executors.

Validate with SWIFT_TREAT_WARNINGS_AS_ERRORS=YES for the app, extensions and tests.
The Xcode 27 App Intents metadata tool still reports that extraction is skipped
when a target does not link AppIntents. No source/compiler fix is required for
that diagnostic; do not add unused frameworks or hide compiler warnings to remove
it. Investigate new Swift errors/warnings independently of these SDK messages.

## Keyboard diagnostics

On the iOS 27 simulator, `cannot add handler to 0 from 0 - dropping` is logged by
Core Animation during keyboard presentation, typing and dismissal. A temporary
control screen with only a standard single-line TextField and Done button
reproduced the same messages without the chat transcript, app picker, animations
or safe-area composer. Replacing the picker keyframe animation did not remove
them, so that speculative change was discarded. Do not suppress system logs or
disable prediction/accessibility to hide these messages. Focus/draft/picker/tab
and reply-following UI tests pass. The previously supplied predictive-keyboard
constraint/frame warnings did not reproduce in these runs; device observation is
still needed if they recur. Extension build versions must match the host app.
