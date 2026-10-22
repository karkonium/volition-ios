# Runtime operations

## Permissions and startup

RootView derives launch/onboarding/access-required/main destinations from current
Screen Time authorization. Foreground entry refreshes authorization; a revoked
permission must show the full access-required gate before MainView’s enforcement
loop runs. See RootDestination, ScreenTimeAuthorization, RootView and
ScreenTimeAccessRequiredView. UI tests use mocked providers.

After authorization, MainView prepares legacy data, reconciles shields/monitoring,
and requires at least one saved app. It refreshes on app changes, foreground entry
and a 30-second loop. Incoming app URLs return to Chat; the App Group pending token
selects the intended saved app. UI navigation state is not a persisted rule schema.

## Personal OpenAI configuration

Copy `Config/Conversation.env.example` to ignored `OpenAppLock/Conversation.env`.
Set OPENAI_API_KEY locally; the client currently uses gpt-4.1-mini. Rebuild/reinstall
when changing the file. Confirm the built app contains the local config without
printing its contents. This is a personal prototype; do not distribute its key.

CONVO_LOG_ENABLED=0 disables temporary conversation tracing. Tagged logs distinguish
key loading, request start/status/validation, model decisions, timer registration,
configured blocker counts and precise local rejection categories. Never log raw
API errors, chat, intentions, tokens or keys; server errors can echo a credential.

## Diagnostics

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
