# Volition — conversation-first MVP

## Architecture

Main app: versioned SwiftData rules and one ConversationArchive hold goals and the
full chat. ConversationCoordinator serializes requests and records real grant
outcomes. OpenAIConversationClient uses stateless Responses requests with strict
JSON decisions using GPT-4.1 mini without reasoning-only request parameters. The app reads OPENAI_API_KEY from OpenAppLock/Conversation.env, copied
into the app bundle during each build. This ignored local file replaces in-app
key entry; rebuild/reinstall after editing it. The bundled key is recoverable from
this personal prototype, so do not distribute a build containing a private key.
Config/Conversation.env.example documents the format. CONVO_LOG_ENABLED=0 disables
all temporary ///CONVO-LOG diagnostics; debug builds enable them by default.
Logs report key presence, request/response stages, HTTP status, recognized API
error codes, transport codes, validation and local grant/persistence outcomes.
They never include credentials, chat text or raw response bodies. HTTP failures
produce actionable chat errors instead of a single generic connection error.

Shared: ConversationGrantStore coordinates an App Group file across processes.
It contains snapshots, independent active app grants, and a short-lived shield request.
ConversationEnforcement changes only Conversation rule stores. On first entry,
VolitionApps disables legacy Schedule/Time/Open rules and splits multi-app
conversation rules into individual profiles. MainView immediately reconciles
shields, monitoring and notifications; legacy persisted data remains recoverable.

Extensions: ShieldConfig offers Request access; ShieldAction writes the token and
opens the main app on iOS 26.5+ (earlier systems require opening it manually).
MainView consumes the pending target on foreground entry. Monitor restores full
Conversation shields at expiry. Raw tokens never enter OpenAI prompts.

## Behavior

The shipping flow is welcome → Screen Time permission → choose apps one at a
time, name each, write how the user wants to use it → Chat. Existing installs
with saved conversation apps go directly to Chat. Navigation exposes only Chat,
Apps and Settings. Apps supports adding, editing and removing individual entries.
Names (1–100 characters) and intentions (1–2,000) are trimmed and required;
categories, websites and duplicate tokens are rejected. Add/Edit opens an empty
picker draft; the first valid individual app commits and closes it automatically.
Bulk/category/website selections remain in the picker with an error. Cancelling
preserves the previous app. The App Name footer asks the user to enter the same
name as the selected app (for example, SoundCloud). Apple’s picker has no public
single-selection option, so this flow enforces the boundary in the app.
V4 rule name/goal and
one dedicated app list store each profile; no schema version change is needed.
Old rule kinds/editors remain source compatibility code but are unreachable.
Their UI suites were removed; domain/migration/enforcement unit tests remain.

The selected saved app name appears above a single message composer. No subject
or nickname field remains. Shield routing selects the stored app automatically.
The warm, respectful coach considers the saved intention, current time, shared
transcript/memory and the latest 100 structured cross-app decisions/outcomes.
Each outcome records app ID/name, reason, timestamp and decision; successful grants
also record their ID, start/expiry and early end or observed expiry. These are
access grants, not claims of measured foreground usage. Full records remain local.

The model can ask, deny, approve 1–10 minutes, or wait 1–5 minutes. Strict output
requires nullable unlock_minutes and wait_minutes, with exclusive local validation.
A wait persists per saved app across selection and relaunch. Chat and the app
selector remain available during both waits and unlocks. Local validation refuses
early approval of the waiting app; another app can be discussed and approved.
The wait banner says “Still blocked” and explains that the countdown is a waiting
period. Expiry permits reconsideration, never automatic access. Independent grants
can coexist for distinct apps, each retaining its original deadline and monitor.
Ending or expiring one grant leaves the others intact. The coach receives all
active unlocks, the selected app’s wait deadline and cross-app access history.
App configuration changes invalidate pending responses/grants.

Above 60 unsummarized messages, older messages are summarized, retaining the newest
30. The full transcript and structured access records stay local. Clearing chat
removes messages/memory and invalidates pending responses; the confirmation explains
that app intentions, access history and an active wait are retained. Network,
refusal, schema, persistence and timer failures grant no new access. Logs never
include credentials, chat text, names, intentions or raw model response bodies.

## Verification status

**Physical-device verification is pending by explicit user choice.** DeviceActivity
requires a monitoring interval of at least 15 minutes. Grants use a 16-minute
interval with warningTime = 16 - grantedMinutes, requesting an end-warning callback
at the short expiry. The monitor handles both warning and interval-end callbacks;
foreground reconciliation also removes expired grants. Callbacks can be delayed by
iOS; short wall-clock enforcement has not been demonstrated on a real device.
There is no claim of exact expiry timing. This remains a personal prototype.

The timer probe source remains available for development, but its menu entry was
removed from the simplified Settings. Physical-device checks remain: 1, 5 and
10 minute grants with the app backgrounded and terminated; verify blocking before
returning to the app so foreground reconciliation cannot mask a delayed callback.

Apple references:
- https://developer.apple.com/documentation/deviceactivity/deviceactivityschedule/warningtime
- https://developer.apple.com/documentation/deviceactivity/deviceactivitycenter/monitoringerror/intervaltooshort
- https://developer.apple.com/documentation/managedsettings/shieldactionresponse

OpenAI references:
- https://developers.openai.com/api/docs/guides/structured-outputs
- https://developers.openai.com/api/docs/models/gpt-4.1-mini

## Local validation (2026-10-20)

- 406 unit tests passed, including real V3→V4 store migration, selection-order
  stability, per-app grant isolation, failed registration, stale callbacks,
  cancellation, shared memory, compaction and transport/schema failures.
- All four Conversation UI tests passed on iPhone 17e and iPad Pro 11-inch (M5),
  iOS 27 simulators. They cover creation with a goal/list, editor validation,
  follow-up/deny/approve/end flows, API-key settings, and history deletion.
- Screenshots from both simulator runs were inspected directly. Xcode MCP and
  computer-control permissions were unavailable; screenshots came from XCUITest.
- Debug builds for generic iOS devices and Release simulator builds succeeded.
- No personal API key was supplied; API transport was verified with URLProtocol
  fixtures and chat/enforcement UI with injected mocks. A live API call and real
  Screen Time expiry remain device acceptance checks.
- The broad iPhone regression ran all 63 UI cases. It found the Conversation
  list-section omission (fixed, with all four feature UI tests subsequently
  passing on both devices). The two remaining deep-link failures reproduce with
  the same assertions on an untouched HEAD checkout on the same iPhone/iOS 27
  runtime. Existing rule-URL routing is preserved; no unrelated routing refactor
  is included. The other 60 UI cases passed in the broad run.

## Env configuration and diagnostics validation (2026-10-21)

- Replaced in-app Keychain entry with ignored `OpenAppLock/Conversation.env`.
  Xcode's synchronized app group copies the resource into the main app bundle;
  no build script or extension credential sharing is required. The local file
  starts with a placeholder; use `Config/Conversation.env.example` on fresh clones.
- Red: new environment tests failed to compile before the provider existed.
  Green: all 412 unit tests and all four Conversation UI tests passed on iPhone
  17e/iOS 27. The env settings/history flow also passed on iPad Pro 11-inch (M5).
  Settings screenshots from both runs were inspected directly.
- Captured live simulator unified-log entries confirm the ///CONVO-LOG tag is
  searchable. Transport fixtures cover HTTP rejection, refusal, incomplete/invalid
  output, credential/body redaction, and the logging off switch. Coordinator tests
  verify actionable API failures leave the app blocked.
- A real request using the user's credential is pending local key configuration
  and a rebuild/install. The original failure cannot be identified retrospectively
  from the previous generic error. No timer or shield-routing behavior changed.

## Model access diagnosis (2026-10-21)

The replacement local key authenticates, but live Responses requests to GPT-5 mini
return HTTP 404/model_not_found even though the models list includes that ID.
A live GPT-4.1 mini Responses request using the same key and strict access-decision
schema returns HTTP 200/completed with a valid decision. The client therefore uses
GPT-4.1 mini and omits the reasoning parameter. No chat history was used in these
synthetic smoke requests, and neither credentials nor raw responses were logged.

The transport contract test failed against the previous model/reasoning payload,
then passed after the switch. All 412 unit tests pass after the change. A second
live smoke request using the exact app instructions, context shape, schema and
output budget returned HTTP 200/completed and passed local decision invariants.

## Chat focus lifecycle

The message input uses a FocusState (nickname entry was removed in the Volition flow). App selection,
sending, leaving Chat, background/inactive transitions, and receiving a grant
clear focus. The input is disabled while a request is pending or a grant is
active. Returning to Chat preserves the draft but does not resurrect a keyboard.
Transcript scrolling supports interactive keyboard dismissal. No UIKit keyboard
notifications are synthesized, and system logging remains enabled.

Investigation reproduced `cannot add handler to 0 from 0 - dropping` from
`com.apple.coreanimation:API` in a separate minimal SwiftUI app consisting only of
NavigationStack and Text, with no OpenAppLock code or text inputs. This warning
is not evidence of an app-owned callback registration failure. A regression UI
test did expose an app issue: nickname focus survived the picker/tab round trip
and brought the keyboard back on Chat re-entry. The focus lifecycle above fixes
that behavior; it does not claim to eliminate OS-internal diagnostic messages.

The iPad focus regression also exposed draft loss when NavigationSplitView
replaces its detail view. The unsent draft now lives in the session coordinator
rather than view-local State. It survives tab/sidebar navigation and remains
unsent and outside persisted chat history until the user presses Send.

Validation: the new focus regression failed on iPhone with stale keyboard focus,
then passed after the focus fix. Its first iPad run exposed draft loss; after
moving the draft to the coordinator, the final regression passed on both iPhone
17e and iPad Pro 11-inch (M5), iOS 27. Final iPad validation included all 412 unit
tests (passed). The existing follow-up/deny/approve/end-unlock UI regression also
passed. Approval screenshots on both devices were inspected directly; no keyboard
remained onscreen, and ending the grant restored input availability. Xcode MCP
was unavailable, so visual validation used XCUITest screenshots. OS-generated
handler warnings remain reproducible in the independent minimal control app;
there is no claim that every Apple keyboard diagnostic is eliminated on device.

## Follow-up keyboard console investigation (2026-10-21)

The user confirmed that opening Chat and focusing the input only produces console
messages: typing works and there is no reported freeze or broken layout. The
additional pasted constraint conflicts involve Apple's TUIPredictionViewCell and
TUICandidateGradientContentLabel, not constraints owned by ConversationView.

A fresh standalone control app with only NavigationStack and a focused standard
multiline TextField reproduced six `cannot add handler` messages from Core
Animation and all 15 UIKBDynamicRenderFactory property messages from UIKit during
keyboard startup. Its visible keyboard was inspected directly. This control has
no OpenAppLock, FamilyControls, conversation client, or coordinator code. The
prediction-cell constraint conflict, private RunningBoard entitlement messages,
and linguistic-asset boot UUID messages were not reproduced in that simulator
control; do not claim the entire device log was reproduced or fixed.

No further app/UI changes were made based only on this log. In particular, do
not suppress system logging, add private Apple entitlements, modify private
keyboard constraints, or disable normal language input to make the console quiet.
The previous focus/draft regressions remain covered by their existing UI tests.

## Volition flow validation (2026-10-21)

- Red: profile/wait tests failed to compile before the new domain behavior existed;
  setup UI test then failed at the missing Add an app button.
- Green: final full unit run passed all 419 tests (454 parameterized executions).
  The full iPhone run passed 419 unit and 13 current UI tests. Subsequent final
  branding/context/focus changes passed both Volition UI flows on iPhone and the
  setup/edit flow on iPad. The updated shield-brand assertion passed in the final
  full unit run.
- Seven selected iPad flows passed: setup, saved intentions, approval/wait states,
  shared conversation, draft/focus lifecycle, chat deletion and onboarding.
  Screenshots from iPhone and iPad were inspected directly. The setup heading was
  shortened after visual review caught truncation. Xcode MCP was unavailable;
  visual checks used XCUITest screenshots instead.
- Two live synthetic OpenAI requests returned HTTP 200, completed, valid strict
  decisions: a concrete messaging task was approved for three minutes; repeated
  scrolling requests with grant history received a three-minute wait. These are
  smoke observations, not a guarantee of identical model decisions. No personal
  conversation was sent, and credentials/raw responses were not logged.
- Physical-device app selection and short background/terminated re-blocking still
  require device acceptance. Simulator flows use injected picker/client/shields.
- Changes remain uncommitted on feat/volition-chat-first, as commits require an
  explicit user request.


## Unlock reliability and coach judgment (2026-10-22)

The old approval path treated a registered timer and attempted shield clears as
success without checking the configured restrictions. It could present a timer
while another configured store still blocked the app. New failing regressions
cover an ignored shield release, overlapping blockers and a persisted grant whose
later reconciliation cannot release the shield.

Shield cleanup now combines the shared defaults registry with the public iOS 26.5
ManagedSettingsStore inventory, so a lost registry entry cannot strand a rule
store. Clears explicitly remove all shield directives and deactivate the store on
supported OS versions; blocking reactivates it. Block/Allow Only transitions also
remove the other mode's stale directives. The retired debug timer probe is reset
before normal enforcement, preventing its independent store surviving the removed
Settings entry. There was no timer-probe record in the retrieved device export;
it is a preventive cleanup, not a confirmed cause of this incident.

Approval cleans inactive/orphaned rule stores, applies the app exception and checks
configured blockers across the app's rule stores. A remaining blocker revokes the
saved grant, stops the timer, restores shields and surfaces the existing failure
message. The coordinator only appends a successful approval after that check.
Reconciliation repeats the check and revokes a persisted grant if a blocker remains.
Configured-state readback is not proof that iOS's visible shield disappeared.

The connected iPhone's prior logs showed clear writes and no immediate monitor
re-block for the recent grants. Its saved legacy schedule was disabled. Those old
logs lacked configured-state readback; they do not establish the exact device-side
cause. Physical-device unlock confirmation is still required.

The coach now asks requested duration when missing, asks stopping/final-opening
plans for repeats, and prefers firm refusal for repeated nonessential access or
broken commitments. It must not use a short wait as automatic permission. A full-
archive activity summary supplies recent cross-app grant counts, granted minutes,
same-app repeats, denials and time since the last grant ended. These records are
not measured foreground usage. Reports of technical failures are taken seriously.

Five live synthetic scenarios returned HTTP 200 and valid strict decisions:
clear task with two requested minutes → approve two; missing duration → ask;
four recent scrolling grants plus another request → deny; two recent grants →
ask for a stopping plan; returning after a wait to continue scrolling → deny.
These are observed smoke results, not guarantees of identical future replies.

Debug launch flag -export-conversation-support exports diagnostic log files,
enforcement state and token-free shield configuration metadata to Documents/
VolitionSupport for Apple's device transfer tool. No API key, bundle, SwiftData
store or conversation transcript is copied. It is not a product settings option.

Final validation for the 2026-10-22 reliability follow-up:
- All 426 unit tests passed (461 parameterized executions). The approval/wait UI
  regression passed and its approval screenshot was inspected directly.
- The signed generic-iOS build succeeded. devicectl reported install outcome
  success for the corrected build on the paired iPhone. A later remote launch
  was denied because the device had locked, so visible unlock verification is
  pending user feedback; installation is not evidence that the bug is resolved.
- A missing FamilyControls import introduced while extending support export was
  corrected and included in the final build/tests/install. The pure LogFilename
  helper is explicitly nonisolated so support export introduces no actor warning.
- Source and diagnostics are uncommitted on fix/reliable-conversation-unlocks.

### October 22 follow-up: independent timers and SoundCloud investigation

Chat and app selection remain available during timers. Independent per-app grants
share transactional enforcement state; approval, expiry, manual end and rollback
modify only the relevant grant. The legacy first-grant JSON field remains readable.
The user confirmed that the “A little breathing room” countdown was a wait; the
new heading explicitly says “Still blocked.” This does not resolve their separate
report that Maps opens but SoundCloud sometimes stays shielded after approval.

The retrieved configuration had no active grant, disabled legacy rules and one
active store per current app, so it cannot establish the cause of that failure.
On iOS 26.5+, releasing a rule now deletes its dedicated store after clearing it;
blocking recreates that store. A real ManagedSettings simulator integration test
checks store removal and preservation of unrelated stores. Readback verifies
configured directives only, never that iOS has actually dismissed a shield.

Debug builds capture the latest attempted approval into Documents/VolitionSupport/
LatestApproval, without restarting the app. The snapshot includes a capture
timestamp, enforcement state, configured store metadata and tagged logs; it
excludes credentials and the chat transcript. Missing source state removes stale
exported state. Physical verification of SoundCloud and background expiry remains
pending until the acceptance result below; do not infer long-run reliability
from configuration readback alone.

Validation: 432 unit tests passed on iPhone, followed by all six affected iPhone
UI tests and all 446 tests (432 unit + 14 UI) in the full iPad run. Inspected
iPhone/iPad screenshots of two simultaneous grants and the explicit wait banner.
The final added readback/unrelated-store assertions and specific local failure
diagnostics passed the full 432-unit iPhone rerun. Eight live synthetic coach
checks returned HTTP 200 and valid decisions, including no extension of an open
app and a purposeful second-app approval. The signed generic iPhone build passed.
The first final installation attempt timed out; the retry succeeded with
CoreDevice reporting com.a5karki.volition installed. An actual SoundCloud-open
acceptance test was subsequently confirmed by the user: “SoundCloud opens.”
This verifies this approved unlock on the new build; repeated use and
background/terminated re-blocking still require longer device observation.

### October 22: single-app choice and name guidance

Add/Edit uses a fresh picker draft and automatically closes after one valid
individual app. Invalid bulk/category/website choices show guidance; cancellation
keeps the original app. The form explains that App Name should match the chosen
app, with SoundCloud as an example. Shared validation is used by both picker and
save. Five focused unit tests plus setup/edit UI passed on iPhone; the full iPad
run passed 447 tests (433 unit + 14 UI). Read iPhone/iPad screenshots of the name
footer and invalid-selection guidance. The signed device build compiled and
CoreDevice confirmed installation. The user confirmed the native Apple picker
closes automatically after choosing one app and the App Name hint appears.
The UI harness separately verifies the flow with synthetic tokens.
