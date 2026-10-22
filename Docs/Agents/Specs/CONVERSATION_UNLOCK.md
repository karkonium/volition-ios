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
The wait banner says **Still blocked** and explains the countdown. Its expiry
permits reconsideration, never automatic access. Additional wait replies do not
restart an already-active wait.

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

ShieldAction records a short-lived target token; on iOS 26.5+ it opens the app.
Earlier systems require opening manually. Foreground consumption selects the saved
app in Chat. Raw Apple tokens never enter the OpenAI context.

## Configuration and evidence

See OPERATIONS.md for ignored personal Conversation.env, tagged diagnostics and
Debug approval snapshots. Snapshots capture enforcement/configured store state
at an actual approval attempt without restarting the app. No API key or transcript
is exported. Never use an inactive-grant snapshot as proof of a failed unlock.

User-verified on iPhone: shield-to-chat routing, genuine SoundCloud/Maps unlocks,
single-app picker auto-dismiss and matching-name hint. During an earlier report,
“A little breathing room” was a wait timer; current copy explicitly says Still
blocked. A successful foreground check does not establish long-running reliability.

The baseline before branding/cleanup passed 447 tests (433 unit + 14 UI), with
screenshots inspected on iPhone/iPad. Live synthetic coach checks returned valid
HTTP 200 decisions for purposeful use, missing duration, repeated scrolling,
repeated requests requiring a stopping plan, returning after a wait, active-app
extension refusal, another-app approval and an active wait refusal.

Pending device observation: repeated use over time, multiple concurrent real-app
grants, and 1/5/10-minute re-blocking while backgrounded or terminated. Confirm
blocking before returning so foreground reconciliation cannot mask a late callback.

## Primary API references

- https://platform.openai.com/docs/api-reference/responses
- https://developer.apple.com/documentation/deviceactivity/deviceactivityschedule/warningtime
- https://developer.apple.com/documentation/managedsettings/managedsettingsstore
- https://developer.apple.com/documentation/familycontrols/familyactivitypicker
