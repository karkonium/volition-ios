# Compatibility boundary

The product exposes only conversation-based access. Old screens, editor navigation
and completed planning docs were removed after the conversation MVP was verified.
The clean baseline is commit `410fc5b`; removed code/docs remain recoverable in Git.

## Retained deliberately

- SwiftData schemas V1–V4, BlockingRule/AppList relationships and migration plan:
  existing installs must still open their databases without resetting user data.
- `VolitionApps.prepare`: disables old schedule/time/open rules and splits legacy
  multi-app conversation selections idempotently. Do not enable old rules again.
- RuleEnforcer, RuleScheduler and shared schedule/limit/open-session stores and
  policies: old monitor callbacks can outlive a UI change. They must handle saved
  snapshots safely and let current reconciliation remove retired restrictions.
- ShieldConfiguration/ShieldAction/Monitor/Report targets, entitlements, bundle IDs
  and App Group: no distribution or extension identity changes during cleanup.
- Legacy pure value models, logic and regression tests. They preserve domain and
  migration expectations even though the old editor screens no longer exist.
- Timer probe cleanup code: resets a previously persisted development shield;
  removing its old menu/screen must not strand an installed debug restriction.

## Load-bearing legacy facts

Schedule times are minutes from midnight. `end <= start` crosses midnight and
belongs to the starting day; equal times mean a 24-hour window. Status is derived.
RulePolicy owns hard-mode gating and temporary pauses. Overlapping enabled rules
use the strictest configured restriction. Old stores are named `rule-<UUID>`.

Time-limit callbacks are day-keyed and must reject stale dates. Confirmed day
starts and authoritative usage have distinct freshness semantics. Old open-session
and pause monitors have dedicated prefixes; never interpret them as conversation
grant activities. Named-store cleanup must preserve unrelated system settings.

The detailed behavior contract is in source comments under `Shared/Models`,
`Shared/Enforcement`, `Shared/Stores` and the corresponding services. Keep the
existing tests; schema/enforcement simplification requires its own migration and
real-device verification task, not a logo or source cleanup.
