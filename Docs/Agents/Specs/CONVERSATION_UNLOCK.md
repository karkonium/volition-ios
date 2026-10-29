# Conversation-first Volition

## Product contract

Welcome → AI sharing choice → Screen Time permission → save apps → Chat. Each profile contains one
individual app token and required name (1–300 characters). Optional structured
intentions and free-text notes (up to 2,000 characters) live alongside the legacy
intention; skipped notes get a neutral default, preserving old validation.
Text is trimmed. Categories, websites, duplicate apps, invalid names and
oversized notes are rejected. Choose App opens a separate empty draft; one valid app closes the picker
automatically. Cancel preserves the original choice. The App Name footer asks for
the selected app’s actual name, with SoundCloud as an example.

Existing installs open Chat after VolitionApps.prepare retires legacy rules and
splits multi-app conversation profiles. Chat, Apps, Insights, Focus and Settings use iPhone tabs/iPad sidebar. Old rule/editor screens are removed;
saved models, migrations and legacy callback handling remain (COMPATIBILITY.md).
The name and intention belong to the saved profile, not a repeated chat subject.

The welcome page explains the three-part access flow with compact steps and
back navigation between onboarding pages. Consent remains explicit and optional.
The saved-app chooser supports name/intention search, marks the current selection,
and distinguishes focus protection from conversation gating and active grants.
Switching or cancelling selection preserves the chat draft. Adding an app uses
three labeled steps, a native single-app picker, and a visible selected-app preview.
The system picker still owns application discovery; tokens never resolve to names
outside Apple's privacy-preserving labels.

## Countdown, pause-first coaching and exceptions

Grants accept 1–30 minutes; deal breaks accept 1–1,440 minutes (24 hours).
A pause/delay means waiting BEFORE opening. A deal means access now followed by
an agreed block. Use the sequence intention → suggested short pause with an optional trigger/emotion
check-in → negotiated deal → last-resort refusal. Suggest ten seconds first rather
than requiring another duration negotiation. Longer pauses and deal terms are
chosen willingly by the user; use deals after a completed pause. Urgent practical tasks remain
proportionate. Explicitly proposed deals are valid consent to discuss terms, not
a reason to bypass the pause-first order. Pause seconds accept 10–1,800; choices
remain visible after the deadline and normal completion needs a check-in answer.

A persistent user may receive a short exception to an accepted deal only after at
least two actual coach pushbacks during its break. Shared state validates the exact
deal and atomically records the override with activation. Across all apps, two
resolved deals cannot be broken in a row: a fulfilled deal must occur between
exceptions. Chat clearing/relaunch do not reset this ledger. Failed activation
restores the original commitment and does not consume an exception.

One Live Activity per actual grant shows its native countdown, including while
the app is suspended. Pre-scheduled local reminders alert at 60/30/10 seconds
remaining; distinct request IDs share one thread because reusing one pending ID
would replace earlier alerts. iOS chooses grouping/presentation and may delay or
suppress delivery. Reminders never govern enforcement. End/expiry/rollback clear
only their grant's reminders/activity. Disabled notifications or Live Activities do
not prevent an unlock. No warning claims that a shield is already reapplied.

## Intentions, progressive intervention and deals

Ask the user to express an intention before access; boredom or deliberate leisure
is a valid answer. Saved profile text alone does not establish today's intention.
Use recent conversation instead of asking the same question again. Repeated
requests bring increasing reflection, stopping-point questions and shorter grants,
then explicit offers: unlock X minutes, followed by Y minutes closed. Avoid
arbitrary punishment or claims about actual usage. Clear practical tasks remain
proportionate, subject to any already accepted cooldown.

Deal offers are app-bound, expire after 30 minutes, and show Accept/Decline.
Nothing unlocks or starts a cooldown before acceptance. Accept validates the
configuration and registers a 1–30 minute grant plus a 1–1,440 minute commitment in
one coordinated App Group transaction. The app stays blocked after that grant
until its original expiry plus the agreed break, including when ended early.
Decline cancels the offer and allows continued conversation. Clear Chat retains
accepted commitments. Failed or rolled-back activation removes the new commitment.
Cooldown expiry only allows reconsideration; it never unlocks automatically.
Existing other-app grants keep their own deadlines. Cooldowns show a static end
time rather than a second countdown.

Show counts of confirmed unlock sessions today: short 1–5 minutes and longer
6–30 minutes, for the selected app and across apps in model context. These count
granted access, not measured foreground use. Never count offers or failed grants.
End unlock immediately hides the affected banner while local re-blocking runs;
a reblocking failure restores it with an error; a later log-save failure must not revive an ended grant. Refreshes captured before ending may not
resurrect a finished banner. Monitor-stop IPC must run outside the grant lock.

## Coach, profiles and reflection

The per-app editor offers optional multi-select purposes and desired changes,
plus a preferred session style and optional free text. Defaults support intentional
use without numerical usage targets. Old free-text intentions remain unchanged.
Structured profiles are optional, keyed by rule ID in the existing private
ConversationArchive JSON; no frozen SwiftData schema or extension DTO changes.

CoachingPolicy owns the prompt. The GPT-5.4 mini coach uses medium reasoning for decisions and low reasoning for
summaries. Each request needs a current stated intention; boredom is a valid one.
Fresh practical tasks can receive short approvals. Rapid repeat unlocks progressively
start with a short pause and optional trigger awareness, then a willingly negotiated
deal. Refusal remains available only after earlier interventions have meaningfully
been tried or discussed in the current pattern. Counts alone, boredom, or declining
a voluntary pause/deal do not justify an early refusal. Existing accepted breaks
still apply, but a gentle reminder or question is the first response to a return.
There is no rigid three-strikes rule, and feelings are never grounds for refusing access.

Strict output includes decision ask/deny/approve/pause/deal/override/wait plus nullable
unlock_minutes, wait_minutes, pause_seconds and block_minutes. Approve/pause/deal/override
require unlock_minutes 1–30. Only deal requires block_minutes 1–1,440. Override requires an eligible shared deal and 1–30 unlock minutes. Only pause
requires 10–1,800 seconds; longer pauses require consent. Legacy
wait output (1–5 minutes) remains a voluntary offer; persisted hard waits and
accepted deal breaks are enforced. Invalid output fails closed.

Reflections persist deadlines, app/configuration binding, planned unlock and
optional emotion choice in the archive. They are separate from hard waits and
active grants. Ten-second pauses begin immediately, can be skipped or cancelled, and
activate once through the existing timer/durable-state/shield checks without a
second API request. Normal completion requires both the elapsed pause and a
check-in choice (including Not sure / Skip). An unanswered check-in stays visible
after the deadline; choosing an option then completes the planned unlock. Explicit
Skip pause still bypasses the soft pause. Longer offers require Start or Skip. Per-app pauses may overlap;
chat and selection remain available. Foreground lifecycle services completion even
outside Chat. Background/termination never starts a grant; overdue pauses complete
on foreground return only after a check-in response, while offers older than 30 minutes expire. Activation is
claimed durably before asynchronous enforcement; interrupted activations are never
replayed on relaunch. Configuration edits, clearing chat or replacing a same-app
request cancel pending reflection. Failure never publishes an unlock.

Only active unlocks use the top timer. Reflection uses an inline card near the
composer, labeled Pausing before opening, with quick optional emotion choices and skip.
Scroll follows a stable bottom target after sending, loading and replies while
near the bottom. Reading older messages suspends automatic following; explicit
send resumes it. Safe-area composer keeps keyboard and latest content apart.

Context includes the selected name/intention/profile, time/timezone, shared
transcript/memory, active grants, existing hard wait, latest 100 access outcomes,
full-archive grant statistics, locally formatted wait times, shared deal exception eligibility, pause-first eligibility, the progressive short-pause recommendation, recent removal feedback, and at most ten reflection records from the past
24 hours (choice/timing/outcome only). Emotion selections are not injected into
transcript or durable summaries. No measured usage or Screen Time inventory is
invented. Technical logs contain no emotions or content. Local activity exports
include reflection/choice/actual outcome. Clear Chat retains profiles, activity log,
access history and hard waits, but cancels pending reflection. Clear Activity Log
retains coaching/enforcement history. More than 60 unsummarized messages triggers
summarization, retaining the newest 30 and the full original local transcript.

## Independent timers and request safety

Chat and the app selector remain available during waits and unlocks. Waits persist
per app across navigation/relaunch/history clearing. Local validation rejects early
approval except a validated deal override; another app can be considered for a real purpose.
Waiting is expressed in the coach reply, without a separate banner or countdown.
Only actual unlocks display top timers; soft reflection is inline. Wait expiry permits reconsideration, never
automatic access. Additional wait replies do not restart an already-active wait.

Distinct apps may have concurrent grants. Each retains its original deadline and
monitor. Chatting or approving another app must not end/extend an existing grant.
Same-app reapproval is rejected. Ending/expiring/rolling back one grant affects
only its exact ID. Cross-app history lets the coach spot attempts to continue the
same impulse through another app.

Coordinator captures request generation, app and configuration; it revalidates
after awaits. App changes/clearing chat invalidate stale responses. Persistence,
network, schema, authorization and registration failures grant no new access.
An unrelated request failure preserves already-active grants. Success reply and
unlock banner are published only after local activation succeeds.

## Enforcement

Shared ConversationGrantStore serializes App Group snapshots, grants, pending
shield token and shield writes with coordinated file transactions. The legacy
first-grant field remains readable; additional grants are optional for old JSON.
All processes agree on state; incomplete/corrupt state grants no exception.

Approval registers an expiry monitor, durably saves the grant, then reconciles
all covering stores under a second transaction. Matching grants subtract only their
application tokens from conversation rules; they never permit categories/domains
or override an independent enabled legacy restriction. Disabled/orphaned rule
stores are cleaned using defaults plus the iOS 26.5+ system store inventory.

On iOS 26.5+, clear/deactivate/delete the released dedicated store; blocking later
recreates it. If configured blockers remain after activation, revoke that new grant,
stop its monitor and show failure. Reconciliation also revokes a later-blocked grant.
Configured readback cannot establish what iOS is currently rendering.

Monitor warning/end callbacks remove only matching expired grant IDs, reapply
shields and stop that monitor. Stale callbacks cannot end another/replacement grant.
Foreground reconciliation runs on configuration changes, app activation and a
30-second loop. DeviceActivity uses at least a 16-minute interval (minimum interval support)
and an end warning at the requested expiry. The interval is max(16, requested minutes + 5), so 30-minute grants are covered. OS callbacks can be late;
do not promise exact wall-clock expiry, especially while backgrounded/terminated.

Shield requests select a route at runtime in one iOS 18+ build: iOS 26.5+ returns
openParentalControlsApp immediately, while older systems schedule a notification
and return defer. Both routes publish lightweight metadata before responding.
The modern route never calls notification APIs or requires notification permission.
Each tap saves a fresh request in lightweight App Group preferences, with a unique
ID, selected token, profile ID and five-minute lifetime. Per-ID acknowledgements
consume requests without erasing a newer request or reviving a consumed one. Shield rendering
and request handling never take the grant file coordinator lock. Notification
scheduling has a bounded completion fallback; every shield callback completes once.
The older-OS deferred response redraws notification/permission/manual-open
instructions. The newer shield explains direct opening with a manual fallback. Notifications deep-link by saved profile ID, never raw Apple token;
they do not unlock anything. Background refreshes leave requests pending until
foreground routing. No notification is a guaranteed delivery or grant.

The minimum deployment target is iOS 18 for the app and all extensions. Newer
store cleanup APIs stay availability-gated. Older-OS routing and actual shield
redraw/notification presentation require older-device verification. The user
confirmed repeated notification-to-chat requests select the correct app and Home
navigation kept working on the notification-only revision. With direct opening
restored using the lock-free request handler, the user also confirmed repeated
direct requests, correct selected apps and working Home navigation. This does
not establish long-running reliability or identify the earlier OS hang's cause.

For repeated requests the coach can ask a concrete, voluntary next-use commitment:
“If we make room for five minutes on SoundCloud now, when would you be comfortable
checking it again?” Discuss this before offering a deal; only an accepted deal creates the enforced block, and activation may still fail.

## Configuration and evidence

See OPERATIONS.md for ignored personal Conversation.env, tagged diagnostics and
Debug approval snapshots. Snapshots capture enforcement/configured store state
at an actual approval attempt without restarting the app. No API key or transcript
is exported. Never use an inactive-grant snapshot as proof of a failed unlock.

User-verified on iPhone: shield-to-chat routing, genuine SoundCloud/Maps unlocks,
single-app picker auto-dismiss, matching-name hint, and repeated notification
and restored direct requests with correct routing and working Home navigation. Waiting previously looked
like an unlock; the current UI removes its banner/countdown entirely. A successful
foreground check does not establish long-running reliability.

Pending device observation: repeated use over time, multiple concurrent real-app
grants, and 1/5/10/30-minute re-blocking while backgrounded or terminated. Confirm
blocking before returning so foreground reconciliation cannot mask a late callback.

## Primary API references

- https://platform.openai.com/docs/api-reference/responses
- https://developer.apple.com/documentation/deviceactivity/deviceactivityschedule/warningtime
- https://developer.apple.com/documentation/managedsettings/managedsettingsstore
- https://developer.apple.com/documentation/familycontrols/familyactivitypicker

## Request selection and activity log

Messages may identify saved apps by name (case/diacritic/punctuation tolerant). One
clear match selects that app before the existing decision request. Ambiguous names
require explicit selection; no model may grant an unbound app. Sending without a
resolvable target keeps the draft, highlights/shakes the picker (respecting Reduce
Motion), and explains how to choose or name an app. Follow-ups can reuse selection.

Settings → Activity Log records timestamp, selected/requested app, message, coach
reply, actual system outcome and grant/intervention metadata. It is a private user
log inside the existing archive, with readable text and JSONL exports. Runtime
diagnostics remain metadata-only. Record failed, cancelled and selection-required
requests as well as model outcomes; an approval is unlocked only after activation
and persistence succeed. Old access events migrate once, with unknown approvals
marked unconfirmed. Clear Chat retains this log; Clear Activity Log removes only
log records, preserving enforcement history/waits. Exports are user-initiated.

## Expansion contract

Storage failures preserve the last valid restrictions; a successful empty fetch
alone may remove them. Enforcement publishes healthy, degraded or failed state.
Grant validity is scoped to its covering app configuration, while pending
responses retain a full request revision. Cancellation immediately restores chat
and owns transport cancellation. Summarization failure uses bounded recent context.

AI consent precedes every transmission and withdrawal cancels pending work. Content
erasure removes transcript, memory, content logs and reason/reply text from retained
minimal active enforcement events. Release builds never bundle personal credentials;
a production coach gateway and public privacy policy remain release blockers.

Insights report grants/access opportunities, never measured usage. Warm/balanced/
direct tone defaults to balanced without changing local policy. Focus protection
covers all or selected saved apps, takes precedence over grants, and persists.
Recurring local weekday periods may cross midnight and last at least 15 minutes;
immediate sessions last 15–180 minutes (25 by default). Explicit ending is allowed.

## Compact interface

The main screens use compact inline navigation, white/adaptive surfaces, subtle
outlined cards and explicit primary/secondary button styles. Read-only information
must not resemble an action: actionable rows have a chevron or an outlined/filled
control. Forms retain native inputs and sheets. Layout uses semantic type, 44-point
minimum touch targets, and adapts to accessibility text and the iPad sidebar.
This presentation change does not alter coaching, consent or enforcement policy.

## Interaction polish

Returning from the Screen Time step to defer AI coaching withdraws any consent
accepted earlier in onboarding. Chat uses a compact review entry point; the full
sharing disclosure appears before explicit re-enablement. Privacy settings group
shared data, local data and erasure controls without hiding withdrawal consequences.
Cancelling a send restores its draft immediately; late completions cannot replace
a newer draft. Failures preserve the editable draft and offer an explicit retry.
Only confirmed local grants show approval and timers; waits stay in coach replies.
Chat notices/grants scroll with history so larger text leaves the composer usable.

## App removal, frustration feedback and short-pause progression

Remove App opens a supportive two-step sheet: ask why, then ask whether requesting
1–30 minutes from the coach would help instead. Users can keep the app, request
temporary access in Chat, or remove it after considering the offer. This is not
an LLM-controlled deletion gate. The alternative is a request, not a promised
unlock, and existing grant/deal safeguards apply. An explicit alternative stays
bound to the app being removed even if its feedback names another saved app. Removal intent, reason, chosen
alternative and actual disposition are recorded privately as high_frustration
feedback, not an emotional diagnosis or a reason for stricter coaching. No reason
or feedback content enters technical diagnostics. Recent feedback is sent as
bounded coaching context; Clear Chat and Clear Activity Log preserve the separate
coaching ledger, as with access history. Failed removal must not be logged removed.

Suggested short pauses progress per app through 10/20/30/40/50/60 seconds as pauses
are actually started within 24 hours, capped at one minute. Unstarted offers and
other apps do not advance the count. The model receives the exact recommendation,
uses it for default check-ins, and still respects willingly chosen longer pauses.
Reply and displayed timer must agree; no silent duration changes after generation.

## Verification

515 domain tests pass, covering compatibility/migrations, independent grants,
30-minute monitor deadlines, reminder identities, consent, pause-first gating,
durable deal exceptions/rollback, progressive short-pause recommendations and
removal feedback persistence/exports/app-bound routing.

Merge validation combines the compact UI/Focus/consent work from GitHub with
progressive coaching, deals, removal and native reminders. Unit regressions cover
unrelated app edits retaining live countdowns and content erasure preserving only
sanitized active-grant proof. Focus changes revoke per-app reminders after durable
state commits; monitor IPC runs outside the grant lock. A new unlock scrolls its
card into view. All 45 iPhone UI flows passed across the broad run and focused reruns, plus
four iPad Focus/consent/privacy/removal flows. Screenshots of the accepted deal
and saved optional profile were inspected. An extra iPad chat run was interrupted
after known XCTest keyboard-animation stalls; production deadlines were unchanged.
The signed device build passes. Real shields/background callbacks still require
device acceptance.

Synthetic live GPT-5.4 mini checks cover intention → pause → deal → last-resort
refusal, practical 30-minute requests and bounded deal exceptions. Additional
checks returned matching 10/30/60-second pauses and a supportive removal-friction
reply with the requested five-minute plan. Smoke checks are not deterministic
model guarantees. The signed iOS 18 generic device artifact includes all five
extensions with matching build versions and the ignored local configuration.
This revision has not been installed on the phone.

Pending device acceptance: the new removal flow and progressive pauses, native
notification/Live Activity permission and delivery, real 30-minute expiry/reblock
while backgrounded or terminated, exception-to-real-shield release, long-running
repetition and older iOS devices. The remaining Core Animation keyboard messages
also reproduce in a temporary plain TextField control; see OPERATIONS.md.
