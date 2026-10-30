# Conversation-first Volition

## Product contract

Welcome → AI sharing choice → Screen Time permission → save apps → Chat. Each profile contains one
individual app token and required name (1–600 characters). Optional structured
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
back navigation between onboarding pages. AI sharing defaults on for an unset
preference; saved opt-outs remain off. The sharing disclosure and Not now choice
remain part of onboarding, and Settings can turn sharing off at any time.
The saved-app chooser supports name/intention search, marks the current selection,
and distinguishes focus protection from conversation gating and active grants.
Switching or cancelling selection preserves the chat draft. Adding an app uses
three labeled steps, a native single-app picker, and a visible selected-app preview.
All three numbered headings sit inside their respective cards. Purpose/change
disclosures use square checkboxes and show Select multiple only while expanded;
collapsed questions do not repeat selected answers. The session-style question
precedes its single-choice menu. Intention guidance gives brief examples of
timing, work use and scrolling goals without labeling the heading optional;
free-text notes can still be left blank.
The system picker still owns application discovery; tokens never resolve to names
outside Apple's privacy-preserving labels.
Each picker presentation has a fresh native view identity and empty draft.
Choosing another single app replaces the previous token; Cancel keeps it. Native
title/icon labels are keyed by token so their display refreshes on replacement.
Saved editor values load once rather than resetting after a child sheet returns.

Send appears gray until an app is selected, but a valid draft can still be tapped
to resolve its saved app name. Unresolved submissions preserve the draft and
briefly outline, enlarge and shake the chooser; Reduce Motion keeps only the
outline feedback. Empty/oversized drafts and in-flight sends remain disabled.

## Countdown, pause-first coaching and exceptions

Grants accept 1–60 minutes; deal breaks accept 1–1,440 minutes (24 hours).
A pause/delay means waiting BEFORE opening. A deal means access now followed by
an agreed block. Use the sequence intention → suggested short pause with an optional trigger/emotion
check-in → negotiated deal → last-resort refusal. Suggest ten seconds first rather
than requiring another duration negotiation. Longer pauses and deal terms are
chosen willingly by the user; favor a deal or choice after two recent started pause
attempts, including early-ended pauses. No completed-pause prerequisite applies. Urgent practical tasks remain
proportionate. A concrete deal offer can be accepted directly without a separate negotiation turn;
its displayed Accept action supplies consent. Pause seconds accept 10–1,800; choices
remain available after the deadline; an emotion answer is never needed for access.

A persistent user may renegotiate an accepted break after two actual coach
pushbacks. Override responses are replacement deal offers, requiring Accept before
any access; Decline leaves the old agreement intact. The replacement break is at
least the remaining old break rounded up plus 15 minutes, minimum 30, maximum
1,440. Repeated broken deals may be renegotiated; they are no longer an absolute
veto. Atomic activation and rollback preserve old terms on failure. Each same-app
broken deal in the last 24 hours adds 60 seconds to suggested pauses, capped at
1,800; longer pauses still require Start. Focus and legacy waits stay authoritative.

Sampled emotion check-ins appear first as a separate message with emotion and
Not sure / Skip buttons. The model's intervention reply and card are withheld until
the user chooses; then a ten-second delay begins automatically or a longer delay/
deal is offered for agreement. This is a presentation step, never emotional
consent to terms or access. It is persisted and survives relaunch.

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
configuration and registers a 1–60 minute grant plus a 1–1,440 minute commitment in
one coordinated App Group transaction. The app stays blocked after that grant
until its original expiry plus the agreed break, including when ended early.
Decline cancels the offer and allows continued conversation. Clear Chat retains
accepted commitments. Failed or rolled-back activation removes the new commitment.
Cooldown expiry only allows reconsideration; it never unlocks automatically.
Existing other-app grants keep their own deadlines. Cooldowns show a static end
time rather than a second countdown.

Show counts of confirmed unlock sessions today: short 1–5 minutes and longer
6–60 minutes, for the selected app and across apps in model context. These count
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

Strict output includes decision ask/deny/approve/pause/deal/choice/override/wait plus nullable
unlock_minutes, wait_minutes, pause_seconds and block_minutes. Approve/pause/deal/choice/override
require unlock_minutes 1–60. Deal, choice and override require block_minutes 1–1,440. Override requires an eligible shared deal, minimum replacement break and 1–60 unlock minutes. Pause and choice
require 10–1,800 seconds; longer pauses require consent. Legacy
wait output (1–5 minutes) remains a voluntary offer; persisted hard waits and
accepted deal breaks are enforced. Invalid output fails closed.

Reflections persist deadlines, app/configuration binding, planned unlock and
optional emotion choice in the archive. They remain separate from hard waits and
active grants. Ten-second delays start automatically after any check-in is answered/skipped; longer offers require Start.
End delay ends only the wait and never grants. After expiry/end, show a quieter
Unlock and bright Keep locked. Explicit Unlock activates once through the existing
timer/durable-state/shield checks without a second model request. Keep locked
cancels the plan without a grant. Neither elapsed time nor emotion input opens an
app automatically, including on foreground return. Pending offers expire after
30 minutes; activation claims are durable and never replayed after relaunch.
Configuration edits, clearing chat or a new same-app request cancel pending offers.
Loading with AI sharing off cancels restored pending offers. Explicit activation
rechecks sharing before and after asynchronous enforcement; a stale saved offer
cannot activate after withdrawal, including preferences changed outside Chat.

Each request samples an independent 50% check-in flag. If the resulting decision
is pause/deal/choice/override, an optional emotion message precedes the terms. It records
context only, never accepting/activating an offer; no extra check-in accompanies
straightforward approvals. Sampling is injectable for deterministic tests. The
bounded recent reflection context carries recorded answers to later requests.

Choice is a validated response with BOTH delay seconds and post-access break
minutes plus one shared unlock duration. Delay starts the selected timer without
another Start confirmation; Deal explicitly accepts its displayed terms and uses
normal activation. Open grants the same bounded duration without a pause/new
break and never counts as a started pause. Until chosen it is neither a deal nor a grant. The model sees
same-app started pause attempts over 24h and preferDeal at two attempts, so it can
move repeated requests toward deals instead of looping through delays. This is
coaching guidance, never a quota or a bypass of accepted breaks/Focus protection.

Active unlocks remain in compact pinned banners above the transcript: unlock
icon, app, remaining time and End unlock. Multiple grants retain independent End
buttons; at most two rows occupy the pinned region, with scrolling for more.
Accessibility text sizes can wrap the row. Transcript scrolling never moves the
banners. Only delays show a separate inline countdown; accepted breaks keep no
countdown. Chat/app selection stay available through every intervention.

Context includes the selected name/intention/profile, time/timezone, shared
transcript/memory, active grants, existing hard wait, latest 100 access outcomes,
full-archive grant statistics, locally formatted wait times, shared deal exception
eligibility, started-pause counts/deal preference, the short-pause recommendation,
recent removal feedback, and at most ten reflection records from the past 24 hours.
Emotion selections are not injected into the transcript or durable summaries.
No measured usage or Screen Time inventory is invented. Technical logs contain
no emotions/content. Private activity exports include choices and actual outcomes.
Clear Chat retains profiles, activity log, access history and hard waits but cancels
pending reflections. Clear Activity Log retains coaching/enforcement history.
More than 60 unsummarized messages triggers summarization, retaining the newest
30 and the full original local transcript.

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
and an end warning at the requested expiry. The interval is max(16, requested minutes + 5), so 60-minute grants are covered. OS callbacks can be late;
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
grants, and 1/5/10/30/60-minute re-blocking while backgrounded or terminated. Confirm
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
Notices scroll with history; compact unlock banners stay pinned above the transcript.
Accessibility sizes wrap the banners and their region remains bounded.

## App removal, frustration feedback and short-pause progression

Remove App opens a supportive two-step sheet: ask why, then ask whether requesting
1–60 minutes from the coach would help instead. Users can keep the app, request
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

538 domain tests pass, covering compatibility/migrations, independent grants,
manual delay completion without an emotion, ending/keeping locked without access,
validated Delay vs Deal terms, sampled check-ins, persisted offers, Focus/waits,
replacement-deal acceptance, repeated renegotiation, longer future pauses and
failed-activation rollback. Late cancelled
UI actions cannot rewrite a published unlock as cancelled.
Recovery with sharing disabled cancels old delay/deal/choice offers, and activation
rechecks current consent. Concurrent logging preserves the original UTC-ms format.

Previously verified iPhone simulator flows include: delay/Keep locked/choice, longer pause
consent, optional emotion with explicit unlock, elapsed delay, early-ended delay,
accepted/declined deal with early end, saved-name routing and two independent
pinned banners at dark/accessibility text sizes. Their screenshots were inspected. The current separate check-in → deal,
check-in → explicit delay unlock, and delay/Keep locked/choice flows also pass;
separate check-in/deal screenshots were inspected.
All 21 synthetic live GPT-5.4 mini cases passed, including direct practical/work
approvals, short pauses, deal preference after two attempts, explicit choice,
existing waits/Focus, last-resort refusal, adamant break renegotiation, repeated
replacement deals, a longer pause after a broken agreement, a credible hour-long
lesson in YouTube and the three-way intervention choice. These are smoke checks, not a
promise of deterministic model behavior.

The signed generic iOS build passes with all five extensions and matching local
ignored configuration. The updated app has not been installed on the phone.
An iPad repeated-entry UI run encountered XCTest's known keyboard-animation
stall; production deadlines were unchanged. See OPERATIONS.md for that runner
limitation and existing device acceptance history.
A focused iPad direct-choice flow passes, including optional emotion presentation,
deal acceptance, pinned banner and End unlock. Both screenshots were inspected.

Pending device acceptance: the new removal flow and progressive pauses, native
notification/Live Activity permission and delivery, real 30/60-minute expiry/reblock
while backgrounded or terminated, exception-to-real-shield release, long-running
repetition and older iOS devices. The remaining Core Animation keyboard messages
also reproduce in a temporary plain TextField control; see OPERATIONS.md.

## Custom check-ins, feedback and flexible choices

Custom emotion replaces the generic Other action with a trimmed 1–160-character
entry. Keep legacy `other` values readable. Custom text lives in bounded recent
reflection context (ten records/24h) and the private activity log, never technical
logs or long-term summaries. A persisted global question timestamp prevents a
second check-in within 120 seconds, including after Clear Chat and across apps.
It advances only when the question is actually offered, not on sampling an ask.

Confirmed unlocks and decisions to keep an app locked offer optional Helpful,
Neutral or Annoying feedback. Ratings attach to the actual local activity outcome,
survive relaunch and Clear Chat, export with the log, and never change restrictions.
Failed/pending activation is not rateable as a completed decision.

Conversation access supports 1–60 minutes with model judgment for credible long
requests. Monitoring extends five minutes past the full grant (minimum 16).
Three-way choice offers Delay, Deal and quieter Open now buttons with explicit
terms. Open uses the same foreground, consent, configuration, Focus/wait and
transaction checks; it never accepts a deal or bypasses an existing commitment.

Saving a selected app without a name highlights/focuses the name card using the
same reduced-motion-aware attention effect as Chat's app selector. A valid shield
request during saved-app setup goes directly to Chat with the saved apps retained;
it never saves unfinished editor drafts or bypasses permission/AI consent.

The custom-entry/feedback/three-way Open flow, one-hour grant, and missing-name
Save attention pass on the owned iPhone simulator. Screenshots were inspected.
Domain tests cover exact two-minute boundary/persistence, malformed custom text,
feedback rollback/eligibility, setup routing and 60-minute monitoring math. Signed
builds pass with Swift warnings treated as errors. Physical-device acceptance of
these new flows and 60-minute background expiry remains pending.
