# Conversation-first Volition

## Product contract

Welcome → Screen Time permission → save apps → Chat. Each profile contains one
individual app token, a required name (1–100 characters) and intention (1–2,000).
Text is trimmed. Categories, websites, duplicate apps and empty/oversized text are
rejected. Choose App opens a separate empty draft; one valid app closes the picker
automatically. Cancel preserves the original choice. The App Name footer asks for
the selected app’s actual name, with SoundCloud as an example.

Existing installs open Chat after VolitionApps.prepare retires legacy rules and
splits multi-app conversation profiles. Chat, Apps and Settings are the only valid
sections, using iPhone tabs/iPad sidebar. Old rule/editor screens are removed;
saved models, migrations and legacy callback handling remain (COMPATIBILITY.md).
The name and intention belong to the saved profile, not a repeated chat subject.

## Coach and history

OpenAIConversationClient uses stateless Responses requests, strict JSON output and
gpt-4.1-mini by default. Read the actual system prompt in that source. The coach
behaves like a loving, respectful friend helping reduce impulsive screen time:
ask requested duration when missing, discuss a stopping/final-opening plan for
repeats, and sometimes refuse nonessential repeated requests outright. Waiting
is not a guaranteed route to approval. No shaming or invented usage claims.

Context includes the selected app’s name/intention, current time/timezone, shared
transcript/memory, active app grants, that app’s wait deadline, the latest 100
structured access outcomes and full-archive activity summaries. Summaries count
confirmed grants/minutes over recent windows, same-app grants, time since the
last observed grant ended and denials. Grants are access opportunities, not
measured foreground use; technical failures must not count as successful access.

Strict output contains reply, decision, unlock_minutes and wait_minutes:

| Decision | Local duration rule |
|---|---|
| ask / deny | Both duration fields null |
| approve | unlock_minutes is an integer 1–10; wait_minutes null |
| wait | wait_minutes is an integer 1–5; unlock_minutes null |

Every structured outcome records app ID/name, reason, reply, decision and time.
Confirmed approvals add grant ID/start/expiry; observed expiry/early end is recorded.
All records and the full transcript stay local. More than 60 unsummarized messages
triggers summarization, keeping the newest 30 and retaining the original archive.
Clear Chat removes messages/memory and invalidates pending requests, while keeping
saved intentions, access history and active waits (explained in its confirmation).

## Independent timers and request safety

Chat and the app selector remain available during waits and unlocks. Waits persist
per app across navigation/relaunch/history clearing. Local validation rejects early
approval for the waiting app; another app can be considered for a real purpose.
Waiting is expressed in the coach reply, without a separate banner or countdown.
Only actual unlocks display timers. Wait expiry permits reconsideration, never
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
30-second loop. DeviceActivity uses a 16-minute interval (minimum interval support)
and an end warning at the 1–10-minute requested expiry. OS callbacks can be late;
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
checking it again?” Do not imply this creates an enforced block or guarantees access.

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

The current suite passes 471 tests (507 parameterized runs), with affected UI flows and log export checked
on iPhone/iPad and a signed device build validated. One iPad timer test hit XCTest
keyboard-animation waits during concurrent automation and passed in isolation.
Earlier live synthetic coach checks returned valid HTTP 200 decisions for
purposeful use, missing duration, repeated scrolling,
repeated requests requiring a stopping plan, returning after a wait, active-app
extension refusal, another-app approval and an active wait refusal. The notification
revision also received a valid HTTP 200 ask decision for a repeated SoundCloud
request, asking about a final opening and a concrete stopping action.

Pending device observation: repeated use over time, multiple concurrent real-app
grants, and 1/5/10-minute re-blocking while backgrounded or terminated. Confirm
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
