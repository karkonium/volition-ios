# Volition iOS robustness audit

Reviewed October 30, 2026, against the existing working copy at `/Users/anand/Documents/volition-ios`. Application code was not changed. Existing uncommitted work was preserved. Temporary regression tests were removed from the project after execution; their source is retained in [audit-evidence/RobustnessAuditTests.swift](/Users/anand/Documents/ChatGPT/volition/audit-evidence/RobustnessAuditTests.swift).

This is a broad source and simulator audit, not a guarantee that every defect has been found. P1 means address before trusting persistence/recovery; P2 means a concrete functional or usability defect to address next. “Source-confirmed” means the relevant control flow was traced, but the failure was not injected through the UI.

## Findings

### 1. P1 — Normal refresh overwrites history that failed to load

**Reproduced by a failing regression test.** Initialization catches a history decode error, leaves the default empty history in memory, and sets `loadFailed`. That flag prevents sending, but `refresh` still calls `persist`. The history store then replaces the archive and deletes records absent from that empty history. Startup reconciliation invokes this refresh automatically; no user erasure action is necessary. This can also discard saved waits and structured app profiles.

Evidence: [initialization](/Users/anand/Documents/volition-ios/OpenAppLock/Services/Conversation/ConversationCoordinator.swift:138), [refresh persistence](/Users/anand/Documents/volition-ios/OpenAppLock/Services/Conversation/ConversationCoordinator.swift:226), [archive replacement and record deletion](/Users/anand/Documents/volition-ios/OpenAppLock/Services/Conversation/ConversationHistory.swift:138).

The regression seeded an unreadable archive; refresh replaced its original 30 bytes with a new 112-byte empty archive. All ordinary write paths, including cancellation, need to respect an unresolved load failure. Recovery should preserve the original data and require successful reload or explicit erasure.

### 2. P1 — Save can report success without committing an app edit

**Reproduced by a failing regression test.** Change an existing app's name, notes, or selected app while leaving its structured profile unchanged. `VolitionApps.save` relies on `ConversationHistoryStore.save` to commit the shared model context. That store returns early when the history is unchanged, even though the rule and app-list models have pending changes. The screen can proceed to enforcement and dismissal while durability depends on a later autosave or unrelated write.

Evidence: [save delegation](/Users/anand/Documents/volition-ios/OpenAppLock/Services/Conversation/VolitionApps.swift:54), [early return](/Users/anand/Documents/volition-ios/OpenAppLock/Services/Conversation/ConversationHistory.swift:111).

With autosave disabled in the regression, Save returned with `context.hasChanges == true`; rolling back restored the original name. Commit the rule transaction explicitly even when the archive requires no changes. Test name-only, notes-only, and token-only edits, including a save failure.

### 3. P2 — Feedback storage failure prevents app removal

**Source-confirmed.** Opening removal must first persist a feedback attempt. If that fails, `attemptID` stays nil and the entire form/Continue path remains disabled. There is no retry or feedback-independent removal action. A failure in optional activity-history storage can therefore prevent the user from removing protection through the app, even when the rule itself could still be saved.

Evidence: [form gate and attempt creation](/Users/anand/Documents/volition-ios/OpenAppLock/Views/Conversation/VolitionAppRemovalView.swift:51), [attempt persistence](/Users/anand/Documents/volition-ios/OpenAppLock/Services/Conversation/ConversationCoordinator.swift:938).

Keep rule removal available independently of feedback persistence; show feedback failure separately.

### 4. P2 — App form validation has inconsistent limits and silent disabled states

**Source-confirmed.** The screen allows Save for names containing 101–300 characters, but the service rejects names above 100. At 301 characters Save becomes disabled, preventing the service's explanation from appearing. Notes over 2,000 characters and a missing app selection also disable Save without identifying the invalid control. General save errors appear near the bottom of a long scroll view, without focusing the failing field.

Evidence: [button validation](/Users/anand/Documents/volition-ios/OpenAppLock/Views/Conversation/VolitionAppsView.swift:202), [service validation](/Users/anand/Documents/volition-ios/OpenAppLock/Services/Conversation/VolitionApps.swift:34), [error rendering](/Users/anand/Documents/volition-ios/OpenAppLock/Views/Conversation/VolitionAppsView.swift:184).

Use one trimmed-input validator for UI and persistence. Show field-specific errors and counts; a Save attempt should reveal/scroll to/focus the first invalid field. The existing missing-name attention is a good partial implementation. Empty optional notes are intentionally supported and should not be flagged as a missing required intention.

### 5. P2 — Focus schedule Save does not identify invalid fields

**Source-confirmed.** Blank/overlong names, no weekdays, a period under 15 minutes, equal start/end times, and an empty custom app selection all collapse into a disabled Save button. There is generic duration help, but no field-specific error, focus, or highlight. A user with several invalid fields cannot tell what remains to fix.

Evidence: [disabled Save](/Users/anand/Documents/volition-ios/OpenAppLock/Views/Focus/FocusView.swift:209), [validation rules](/Users/anand/Documents/volition-ios/Shared/Focus/FocusProtection.swift:13).

Expose each validation result beside its control and guide a failed Save attempt to the first problem.

### 6. P2 — Focus can retain a selection containing only removed apps

**Source-confirmed.** Focus stores saved-rule IDs. Removing an app disables its rule, but existing Focus periods and screen selection state retain that ID. The picker hides disabled apps, while Save/Start only check whether the ID set is empty. With another saved app still present, the user can start or save Focus containing only an invisible, removed app; it protects none of the currently saved apps.

Evidence: [Start checks](/Users/anand/Documents/volition-ios/OpenAppLock/Views/Focus/FocusView.swift:61), [visible app filter](/Users/anand/Documents/volition-ios/OpenAppLock/Views/Focus/FocusView.swift:144), [schedule validation](/Users/anand/Documents/volition-ios/OpenAppLock/Views/Focus/FocusView.swift:209), [ID-based protection](/Users/anand/Documents/volition-ios/Shared/Focus/FocusProtection.swift:56).

Validate the intersection with currently enabled app IDs. Explain unavailable selections and require reselection; do not convert an empty custom selection into “all apps.”

### 7. P2 — Long chat input disables Send without an explanation

**Source-confirmed.** Paste more than 4,000 characters into Chat: Send becomes disabled without a count or length error. The UI checks raw length while the service checks trimmed length, so whitespace can also make the UI reject input the service would accept.

Evidence: [composer validation](/Users/anand/Documents/volition-ios/OpenAppLock/Views/Conversation/ConversationView.swift:315), [service validation](/Users/anand/Documents/volition-ios/OpenAppLock/Services/Conversation/ConversationCoordinator.swift:265).

Keep the draft, show the applicable limit and overage, and share the same normalization/validation rule.

### 8. P2 — Removal reason has an undisclosed length limit

**Source-confirmed.** The reason field permits unrestricted typing/pasting, but Continue silently disables above 2,000 characters. Its helper text does not state that limit. Blank input also has no attempted-submit guidance.

Evidence: [reason field and Continue](/Users/anand/Documents/volition-ios/OpenAppLock/Views/Conversation/VolitionAppRemovalView.swift:44).

Add a count and inline validation. Keep this distinct from the feedback-storage dead end in finding 3.

### 9. P2 — Clear Chat failure is invisible on the initiating screen

**Source-confirmed.** On persistence failure, `clearHistory` restores the old history and sets `conversation.errorMessage`. Coach Settings invokes it but does not render that error or a local result. The confirmation closes and the screen gives no indication that clearing failed; the user must return to Chat to discover it.

Evidence: [failure handling](/Users/anand/Documents/volition-ios/OpenAppLock/Services/Conversation/ConversationCoordinator.swift:589), [settings action](/Users/anand/Documents/volition-ios/OpenAppLock/Views/Conversation/ConversationSettingsView.swift:62).

Return a result and display failure/retry in Coach Settings, following the existing Activity Log and Privacy patterns.

### 10. P2 — Erasure also deletes saved structured app intentions

**Source-confirmed; inconsistent with the displayed erasure explanation.** Privacy says saved app intentions remain, but `eraseCoachingContent` builds a fresh history without copying `usageProfiles`. The saved purposes, desired changes, and session style disappear, even though the app remains saved. Free-text `conversationGoal` survives because it lives on the rule. For users who skipped free text, their meaningful structured intentions are lost.

Evidence: [erasure](/Users/anand/Documents/volition-ios/OpenAppLock/Services/Conversation/ConversationCoordinator.swift:620), [structured intentions](/Users/anand/Documents/volition-ios/OpenAppLock/Services/Conversation/ConversationUsageProfile.swift:3), copy key `expansion.eraseCoachingHelp` in [Copy.xcstrings](/Users/anand/Documents/volition-ios/Shared/Copy.xcstrings).

Preserve saved app configuration, or explicitly disclose and separately confirm its deletion.

### 11. P2 — An accidental sheet dismissal loses unsaved setup

**Source-confirmed.** App and Focus editors block interactive dismissal only while saving. Swiping the sheet away after entering a name, notes, profile answers, or a schedule discards the draft without warning or recovery. App Cancel also discards immediately.

Evidence: [app editor](/Users/anand/Documents/volition-ios/OpenAppLock/Views/Conversation/VolitionAppsView.swift:264), [Focus editor](/Users/anand/Documents/volition-ios/OpenAppLock/Views/Focus/FocusView.swift:212).

Track dirty state and offer Keep editing/Discard, or retain the draft for reopening. Preserve intentional shield-request routing behavior.

### 12. P2 — Diagnostic read/export/delete errors are hidden

**Source-confirmed.** Diagnostic file reads become empty text on failure. Export failure removes the Share control rather than explaining the failure. Clear All ignores deletion failures, so the action may leave logs behind without telling the user.

Evidence: [read/delete fallback](/Users/anand/Documents/volition-ios/OpenAppLock/Services/LogStore.swift:40), [clearAll](/Users/anand/Documents/volition-ios/OpenAppLock/Services/LogStore.swift:79), [export control](/Users/anand/Documents/volition-ios/OpenAppLock/Views/Settings/DiagnosticLogsView.swift:105).

Distinguish empty from unreadable, keep Export available with an error/retry state, and report failed deletions. Failures here should remain isolated from enforcement.

### 13. P2 — Editing a Focus schedule at monitor capacity cannot replace its old registration

**Source-confirmed boundary case.** Changing start/end creates a different activity name. Registration checks the union of all existing names and new names before retiring the old one. At the app's 20-monitor limit, a one-for-one edit is rejected as 21 monitors, even though the final state needs only 20. Focus shows only a generic save error.

Evidence: [register before removal](/Users/anand/Documents/volition-ios/Shared/Focus/FocusProtection.swift:87), [activity identity](/Users/anand/Documents/volition-ios/Shared/Focus/FocusProtection.swift:34), [capacity](/Users/anand/Documents/volition-ios/Shared/Platform/MonitoringCapacity.swift:7).

Provide a safe replacement strategy with rollback, or explicitly reserve capacity and explain how to recover. Never evict unrelated grant monitors.

## Additional risks and release gaps

These are not included in the 13 concrete findings above:

- **Focus concurrency:** `updateFocus` reads the previous state before entering the grant transaction and restores `focus.json` outside that transaction on failure. Cross-process interleavings deserve a fault-injection test; rollback must not overwrite a newer policy. [Implementation](/Users/anand/Documents/volition-ios/Shared/Enforcement/ConversationEnforcement.swift:16).
- **Long-history performance:** history loading fetches/decodes all records, and each changed save fetches all records and re-encodes every retained message/access/activity entry on the main actor. Reflections, removals, and access history grow without a demonstrated scale benchmark. Measure thousands of entries before claiming long-term responsiveness. [Implementation](/Users/anand/Documents/volition-ios/OpenAppLock/Services/Conversation/ConversationHistory.swift:88).
- **Release coach is intentionally unavailable:** Release injects `UnavailableCoachService`, and the direct client throws outside DEBUG. A Release build can compile but cannot provide the core coaching/unlock flow. This is an existing prototype distribution boundary, not a recommendation to ship personal credentials. A production service path is still needed. [App configuration](/Users/anand/Documents/volition-ios/OpenAppLock/OpenAppLockApp.swift:163), [client](/Users/anand/Documents/volition-ios/OpenAppLock/Services/Conversation/OpenAIConversationClient.swift:129).
- **Real-device acceptance remains necessary:** actual native picker authorization, OS-visible shield dismissal, grant expiry while backgrounded/terminated, reboot, revoked permissions, repeated direct requests, denied notifications, and Live Activity behavior cannot be established with mocked simulator enforcement.
- **Older OS coverage:** the deployment target is iOS 18, but only iOS 27 was available for execution. Older notification-based routing and minimum-OS layout/runtime behavior remain unverified.

## Check matrix and evidence

| Level | Checks performed | Result / limit |
|---|---|---|
| Compilation | Debug app, extensions, unit/UI test targets; complete concurrency configuration; warnings treated as errors | Passed Swift compilation |
| Existing unit suite | Domain rules, schedules, grants, enforcement, cancellation, migration, request routing, copy, diagnostics | 538 tests in 84 suites passed |
| Targeted failure probes | Unreadable history preserved; unchanged profile still commits rule edits | Both tests failed, confirming findings 1–2 |
| Form behavior | App editor, Focus, chat, removal, custom emotion bounds | Findings 4–8; existing missing-name guidance present |
| Persistence | Save boundaries, rollback, archive migration/read failures, erasure | Findings 1–3 and 9–10; additional concurrency risk noted |
| Lifecycle / enforcement | Startup/foreground reconciliation, stale callbacks, grant identity, monitor capacity | Existing unit coverage passes; findings 6/13; real-device checks pending |
| Privacy / diagnostics | Consent cancellation, export erasure, clear actions, error surfaces | Findings 9–10/12; no real credentials printed or transmitted |
| Accessibility / presentation | Focus handling, field guidance, dismissal, large-text UI test | Targeted UI results recorded below; VoiceOver and all-device coverage pending |
| Release | Optimized simulator build and service configuration review | Build result recorded below; coach unavailable by design |

### Build/test outcomes and warnings

- **Debug:** successful build and 538/538 existing unit tests passed. [Log](/Users/anand/Documents/ChatGPT/volition/audit-evidence/debug-build-and-unit-tests.log).
- **Release:** optimized simulator build succeeded with `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES`. [Log](/Users/anand/Documents/ChatGPT/volition/audit-evidence/release-build.log).
- **New probes:** 2 tests failed with 3 assertions, reproducing findings 1 and 2. These are intentionally unmet robustness expectations, separate from the passing baseline suite. [Source](/Users/anand/Documents/ChatGPT/volition/audit-evidence/RobustnessAuditTests.swift), [log](/Users/anand/Documents/ChatGPT/volition/audit-evidence/regression-probes.log).
- **Targeted UI attempt:** requested missing-name/picker cancellation, Focus enforcement, and large-text keyboard tests on a dedicated iPhone 18 Pro simulator. Execution stalled at the first app launch for approximately three minutes; a simulator screenshot request was also delayed and eventually returned a black frame. The run was stopped. No UI test pass or visual-layout acceptance is claimed. [Attempt log](/Users/anand/Documents/ChatGPT/volition/audit-evidence/ui-attempt.log).
- **Build warnings:** App Intents metadata extraction is skipped for targets without an AppIntents dependency (7 occurrences in Debug/test build, 5 in Release). These are tool-generated warnings, not Swift compiler warnings; adding an unused framework is not a functional fix.
- **Runtime diagnostics:** the passing unit suite emitted Core Data's “Migration was completed by another client” warning during migration tests. The UI runner emitted a duplicate Apple accessibility class warning involving WebKit/WebCore. These observations do not establish app defects; their production relevance/root cause remains unverified. The UI launch stall is reported as a verification blocker, not attributed to that warning without evidence.

### Recommended repair order and acceptance tests

1. Protect failed history loads from every ordinary write; verify byte-for-byte preservation through startup, refresh, consent changes, and cancellation. Provide explicit retry/recovery.
2. Make app-save durability independent of archive deduplication; verify edits survive a fresh context/relaunch and that injected write errors preserve the draft.
3. Separate removal from feedback-storage success, and invalidate unavailable Focus app selections.
4. Centralize field validation. Cover blank/whitespace-only values, exact limits and limit+1, duplicate apps, no weekdays, equal/short/overnight times, and pasted long text. Errors must be visible near the field and accessible without relying on color alone.
5. Repair Clear Chat/diagnostics result reporting, erasure semantics, and dirty-draft handling.
6. Exercise monitor-capacity replacement, concurrent Focus updates with write failures, and large-history performance.
7. Re-run UI checks on a responsive simulator, including iPad, largest accessibility type, VoiceOver focus, Reduce Motion, keyboard visibility, retry, and double-tap behavior. Then perform real-device enforcement acceptance on both current and minimum supported OS routes.
