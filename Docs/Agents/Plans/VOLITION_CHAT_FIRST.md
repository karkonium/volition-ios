# Volition chat-first implementation

Scope: replace the user-facing schedule/time/open-limit flow with Chat, Apps and
minimal Settings. First-run Screen Time permission is followed by app setup.
Each saved app has exactly one application token, a required name and intention.
Reuse V4 conversation rule/name/goal storage to avoid unnecessary schema churn.
Retire legacy rules and split existing multi-app conversation rules idempotently;
refresh enforcement and scheduling immediately to remove old shields/monitors.

Coach: warm, loving and respectful, never shaming. Consider saved intention,
shared transcript, current time and structured cross-app access outcomes/reasons.
Approve 1–10 minutes, ask, deny, or wait 1–5 minutes. Waits are per app, persisted
across navigation/relaunch and history clearing. Chat and other-app requests remain
available. Expiry permits reconsideration, never automatic access. Independent
grants preserve each app’s original deadline.

Implementation order:
1. Red tests for profile validation/migration, decision validation, persisted
   cooldown, saved-name context and structured access history.
2. Implement profile service and coach decision/history/coordinator changes.
3. Replace navigation and setup/App editing flow; simplify Chat and Settings.
4. Focused tests, full unit suite, new iPhone/iPad UI flows and screenshot review.
5. Update agent docs and report device-only timer verification as pending.

No commit unless requested. Legacy schema/code remains for data compatibility,
but no legacy blocking controls remain reachable in the shipping interface.

## Unlock reliability and stricter coach follow-up (2026-10-22)

Reproduce stored-but-still-shielded grants with a shield backend that ignores
releases. Verify an approval is rejected/revoked unless all relevant Volition
stores report the selected app unshielded. Clean disabled/orphaned rule stores
using both the defaults registry and iOS 26.5 store discovery; explicitly deactivate
cleared stores (reactivate when blocking). Reset the retired timer probe before
normal enforcement, preventing an independent debug shield from surviving the
removed menu. Keep configuration readback distinct from OS-visible confirmation.
Add tagged grant/reconciliation diagnostics without tokens or conversation text.

Coach: supply computed recent granted minutes/counts and time since last grant,
plus full recent structured history. Ask duration/stopping plans when missing;
deny some repeated nonessential requests rather than automatically treating a
short wait as a route to approval. Use live synthetic scenario checks and local
regressions, then full unit and affected UI tests. Device acceptance remains
necessary if the paired phone cannot connect.

## Continue chatting during timers (2026-10-22)

Device feedback clarified that the latest countdown was a wait ("A little
breathing room"), not an approved grant. Make it explicitly say Still blocked.
Keep the composer/app picker usable during waits and grants. Support independent
per-app grants with exact-ID expiry/end; asking for another app cannot end, extend
or overwrite the first. Same-app reapproval cannot extend an existing grant.
Waits are per app and survive relaunch/history clearing; chat remains available,
but a local active wait still prevents granting that app. The coach sees active
unlocks, selected wait and cross-app history, and judges another app's purpose.
Preserve old single-grant JSON and archive compatibility. Test two grants, isolated
expiry/failure, repeated chat, per-app waiting, relaunch and the actual UI flow.

## SoundCloud-specific follow-up

Read the paired device’s configuration and compare profile/store identity. At the
retrieved instant no grant was active, both legacy rules were disabled, and Maps
and SoundCloud each had one current configured rule. This is not a capture of
the reported failed approval. Red/green a real ManagedSettings integration test
for deleting only the released store, then use that supported release mechanism
on iOS 26.5+. Capture every real Debug approval attempt into LatestApproval with
a timestamp, enforcement state and configured store metadata; snapshots must not
retain old state when its source disappears. Run all units and iPhone/iPad UI
flows, inspect screenshots, compile/install the device build and require an actual
SoundCloud approval/open test. Do not claim the root cause is established by an
inactive-grant snapshot or that configured state proves OS-visible access.

Acceptance: signed final build installed successfully on the paired iPhone after
one timed-out attempt. The user tested a genuine “Unlocked until” SoundCloud
grant and confirmed “SoundCloud opens.” Unit and UI validation passed as recorded
in the feature spec. Longer-term repetition and background expiry remain unverified.
