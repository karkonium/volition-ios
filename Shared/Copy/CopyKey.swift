import Foundation

/// The single index of every user-facing string in the app. The prose and all
/// typography live in `Shared/Copy.xcstrings`, keyed by these raw values;
/// code only ever references the symbolic case. `nonisolated` so shield/monitor
/// extension code (outside the MainActor default) can resolve copy.
nonisolated enum CopyKey: String, CaseIterable {
    case conversationChatHere = "conversation.conversationChatHere"
    case conversationDirectRequestInstructions = "conversation.conversationDirectRequestInstructions"
    case conversationNotificationBody = "conversation.conversationNotificationBody"
    case conversationRequestInstructions = "conversation.conversationRequestInstructions"
    case conversationNotificationInstructions = "conversation.conversationNotificationInstructions"
    case conversationContinueInVolition = "conversation.conversationContinueInVolition"
    case conversationEnableNotifications = "conversation.conversationEnableNotifications"
    case conversationNotificationSettings = "conversation.conversationNotificationSettings"
    case conversationNotificationHelp = "conversation.conversationNotificationHelp"
    case conversationSelectAppHelp = "activity.conversationSelectAppHelp"
    case conversationAmbiguousApp = "activity.conversationAmbiguousApp"
    case activityLogTitle = "activity.activityLogTitle"
    case activityPending = "activity.activityPending"
    case activityUnlocked = "activity.activityUnlocked"
    case activityAsked = "activity.activityAsked"
    case activityDenied = "activity.activityDenied"
    case activityWait = "activity.activityWait"
    case activityFailed = "activity.activityFailed"
    case activityCancelled = "activity.activityCancelled"
    case activityUnconfirmed = "activity.activityUnconfirmed"
    case activityInterrupted = "activity.activityInterrupted"
    case activityInterruptedHelp = "activity.activityInterruptedHelp"
    case activityBlockedByWait = "activity.activityBlockedByWait"
    case activityAlreadyUnlocked = "activity.activityAlreadyUnlocked"
    case activitySelectionRequired = "activity.activitySelectionRequired"
    case activityNoApp = "activity.activityNoApp"
    case activityEmpty = "activity.activityEmpty"
    case activityPrivacy = "activity.activityPrivacy"
    case activityExportError = "activity.activityExportError"
    case activityExport = "activity.activityExport"
    case activityExportText = "activity.activityExportText"
    case activityExportJSONL = "activity.activityExportJSONL"
    case activityClear = "activity.activityClear"
    case activityClearHelp = "activity.activityClearHelp"
    case volitionApps = "volition.volitionApps"
    case volitionAddApp = "volition.volitionAddApp"
    case volitionSetupTitle = "volition.volitionSetupTitle"
    case volitionSetupHelp = "volition.volitionSetupHelp"
    case volitionStartChat = "volition.volitionStartChat"
    case volitionAppName = "volition.volitionAppName"
    case volitionAppNameHelp = "volition.volitionAppNameHelp"
    case volitionPickOneHelp = "volition.volitionPickOneHelp"
    case volitionIntention = "volition.volitionIntention"
    case volitionIntentionHelp = "volition.volitionIntentionHelp"
    case volitionSaveApp = "volition.volitionSaveApp"
    case volitionEditApp = "volition.volitionEditApp"
    case volitionRemoveApp = "volition.volitionRemoveApp"
    case volitionRemoveMessage = "volition.volitionRemoveMessage"
    case volitionAppsHelp = "volition.volitionAppsHelp"
    case volitionWelcome = "volition.volitionWelcome"
    case volitionWelcomeDescription = "volition.volitionWelcomeDescription"
    case volitionChatEmpty = "volition.volitionChatEmpty"
    case volitionWaiting = "volition.volitionWaiting"
    case volitionWaitHelp = "volition.volitionWaitHelp"
    case volitionWaitError = "volition.volitionWaitError"
    case volitionCoachSettings = "volition.volitionCoachSettings"
    case volitionPrivacy = "volition.volitionPrivacy"
    case volitionClearHelp = "volition.volitionClearHelp"
    case volitionSaveError = "volition.volitionSaveError"
    case volitionSingleAppError = "volition.volitionSingleAppError"
    case volitionNameError = "volition.volitionNameError"
    case volitionIntentionError = "volition.volitionIntentionError"
    case volitionDuplicateError = "volition.volitionDuplicateError"
    case volitionAccessHistory = "volition.volitionAccessHistory"
    case volitionRetry = "volition.volitionRetry"
    case conversationEnvironmentHelp = "conversation.conversationEnvironmentHelp"
    case conversationEnvironmentConfigured = "conversation.conversationEnvironmentConfigured"
    case conversationEnvironmentMissing = "conversation.conversationEnvironmentMissing"
    case conversationDiagnosticsEnabled = "conversation.conversationDiagnosticsEnabled"
    case conversationDiagnosticsDisabled = "conversation.conversationDiagnosticsDisabled"
    case conversationDiagnosticsHelp = "conversation.conversationDiagnosticsHelp"
    case conversationAuthenticationError = "conversation.conversationAuthenticationError"
    case conversationPermissionError = "conversation.conversationPermissionError"
    case conversationQuotaError = "conversation.conversationQuotaError"
    case conversationRateLimitError = "conversation.conversationRateLimitError"
    case conversationRequestError = "conversation.conversationRequestError"
    case conversationServiceError = "conversation.conversationServiceError"
    case conversationResponseError = "conversation.conversationResponseError"
    case conversationApprovalOne = "conversation.approvalOne"
    case conversationOpenManually = "conversation.openManually"
    case conversationRuleTitle = "conversation.conversationRuleTitle"
    case conversationRuleExample = "conversation.conversationRuleExample"
    case conversationDefaultName = "conversation.conversationDefaultName"
    case conversationGoalValidation = "conversation.conversationGoalValidation"
    case conversationAppsValidation = "conversation.conversationAppsValidation"
    case conversationBlockedStatus = "conversation.conversationBlockedStatus"
    case conversationChatTitle = "conversation.conversationChatTitle"
    case conversationChooseApp = "conversation.conversationChooseApp"
    case conversationMessagePrompt = "conversation.conversationMessagePrompt"
    case conversationSend = "conversation.conversationSend"
    case conversationEndUnlock = "conversation.conversationEndUnlock"
    case conversationRequestAccess = "conversation.conversationRequestAccess"
    case conversationWaiting = "conversation.conversationWaiting"
    case conversationHistoryClear = "conversation.conversationHistoryClear"
    case conversationMissingKey = "conversation.conversationMissingKey"
    case conversationNetworkError = "conversation.conversationNetworkError"
    case conversationStaleRequest = "conversation.conversationStaleRequest"
    case conversationGrantFailed = "conversation.conversationGrantFailed"
    case conversationGrantActive = "conversation.conversationGrantActive"
    case conversationUnlockedUntil = "conversation.conversationUnlockedUntil"
    case conversationRequestMarker = "conversation.conversationRequestMarker"
    case conversationApprovalMarker = "conversation.conversationApprovalMarker"
    case conversationGrantEnded = "conversation.conversationGrantEnded"
    case conversationGrantExpired = "conversation.conversationGrantExpired"
    case conversationTargetGeneric = "conversation.conversationTargetGeneric"
    case conversationCancel = "conversation.conversationCancel"
    case conversationStorageError = "conversation.conversationStorageError"

    // Walking-skeleton seeds (more added per surface in later tasks):
    case onboardingRequesting = "onboarding.requesting"

    // MARK: - RuleEditorView
    // (rule-actions-menu keys removed post-#38 merge: rule actions moved to
    // RuleDetailSheet, which uses the parallel ruleDetail.* keys.)
    case ruleEditorAppListMultipleSummaryFormat = "ruleEditor.appListMultipleSummaryFormat"

    // MARK: - RuleDetailSheet
    case ruleDetailNoAppsPlaceholder = "ruleDetail.noAppsPlaceholder"
    case ruleDetailAppListSummaryFormat = "ruleDetail.appListSummaryFormat"


    // MARK: - RuleDraft
    case ruleDraftValidationFailedStartEndTimesTooCloseMessage = "ruleDraft.validationStartEndTimesTooCloseMessage"
    case ruleDraftValidationFailedStartTimeTooCloseToMidnightMessage = "ruleDraft.validationStartEndTimesTooCloseToMidnightMessage"

    // MARK: - SettingsView
    case settingsLogsRowLabel = "settings.logsRowLabel"
    case settingsNavigationTitle = "settings.navigationTitle"


    // MARK: - DiagnosticLogsView
    case diagnosticsNoLogsMessage = "diagnostics.noLogsMessage"
    case diagnosticsDaysSectionHeader = "diagnostics.daysSectionHeader"
    case diagnosticsDaysSectionFooter = "diagnostics.daysSectionFooter"
    case diagnosticsClearAllLogsButton = "diagnostics.clearAllLogsButton"
    case diagnosticsClearLogsConfirmationTitle = "diagnostics.clearLogsConfirmationTitle"
    case diagnosticsCancelButton = "diagnostics.cancelButton"
    case diagnosticsClearLogsConfirmationMessage = "diagnostics.clearLogsConfirmationMessage"
    case diagnosticsNavigationTitle = "diagnostics.navigationTitle"
    case diagnosticsNoEntriesPlaceholder = "diagnostics.noEntriesPlaceholder"

    // MARK: - OnboardingView — onboarding.requesting migrated in Task 1
    case onboardingAllowScreenTime = "onboarding.allowScreenTime"
    case onboardingScreenTimeFrameworkBullet = "onboarding.screenTimeFrameworkBullet"
    case onboardingActivityStaysPrivateBullet = "onboarding.activityStaysPrivateBullet"
    case onboardingChangeAnytimeBullet = "onboarding.changeAnytimeBullet"
    case onboardingAccessDeclinedMessage = "onboarding.accessDeclinedMessage"
    case onboardingOpenSettingsButton = "onboarding.openSettingsButton"
    case onboardingContinueButton = "onboarding.continueButton"

    // MARK: - Nav shell: MainSidebarView + AppSection
    case navAppTitle = "nav.appTitle"
    case navSettingsSectionTitle = "nav.settingsSectionTitle"


    // MARK: - RuleStatus
    case statusDisabled = "status.disabled"
    case statusNoDaysSelected = "status.noDaysSelected"
    case statusResumesIn = "status.resumesIn"
    case statusActiveLeft = "status.activeLeft"
    case statusStartsIn = "status.startsIn"
    case statusResetsIn = "status.resetsIn"
    case statusCountdownMinutes = "status.countdownMinutes"
    case statusCountdownHours = "status.countdownHours"
    case statusCountdownDays = "status.countdownDays"

    // MARK: - UsageDisplay
    case usageSubtitleSeparator = "usage.subtitleSeparator"

    // MARK: - RuleKind
    case ruleKindScheduleDisplayName = "ruleKind.scheduleDisplayName"
    case ruleKindTimeLimitDisplayName = "ruleKind.timeLimitDisplayName"
    case ruleKindOpenLimitDisplayName = "ruleKind.openLimitDisplayName"
    case ruleKindScheduleExampleText = "ruleKind.scheduleExampleText"
    case ruleKindTimeLimitExampleText = "ruleKind.timeLimitExampleText"
    case ruleKindOpenLimitExampleText = "ruleKind.openLimitExampleText"

    // MARK: - Weekday
    case weekdayShortLabelS = "weekday.shortLabelS"
    case weekdayShortLabelM = "weekday.shortLabelM"
    case weekdayShortLabelT = "weekday.shortLabelT"
    case weekdayShortLabelW = "weekday.shortLabelW"
    case weekdayShortLabelF = "weekday.shortLabelF"
    case weekdaySundayAbbreviation = "weekday.sundayAbbreviation"
    case weekdayMondayAbbreviation = "weekday.mondayAbbreviation"
    case weekdayTuesdayAbbreviation = "weekday.tuesdayAbbreviation"
    case weekdayWednesdayAbbreviation = "weekday.wednesdayAbbreviation"
    case weekdayThursdayAbbreviation = "weekday.thursdayAbbreviation"
    case weekdayFridayAbbreviation = "weekday.fridayAbbreviation"
    case weekdaySaturdayAbbreviation = "weekday.saturdayAbbreviation"
    case weekdayEveryDaySummary = "weekday.everyDaySummary"
    case weekdayWeekdaysSummary = "weekday.weekdaysSummary"
    case weekdayWeekendsSummary = "weekday.weekendsSummary"
    case weekdayNeverSummary = "weekday.neverSummary"

    // MARK: - RulePreset
    case presetMorningFocusName = "preset.morningFocusName"
    case presetDeepWorkName = "preset.deepWorkName"
    case presetEveningResetName = "preset.eveningResetName"
    case presetLightsOutName = "preset.lightsOutName"
    case presetFamilyDinnerName = "preset.familyDinnerName"
    case presetScreenFreeSundayName = "preset.screenFreeSundayName"
    case presetFocusSectionTitle = "preset.focusSectionTitle"
    case presetFocusSectionSubtitle = "preset.focusSectionSubtitle"
    case presetRestSectionTitle = "preset.restSectionTitle"
    case presetRestSectionSubtitle = "preset.restSectionSubtitle"
    case presetBalanceSectionTitle = "preset.balanceSectionTitle"
    case presetBalanceSectionSubtitle = "preset.balanceSectionSubtitle"

    // MARK: - ShieldPresentation
    case shieldBlockedTitle = "shield.blockedTitle"
    case shieldBlockedSubtitle = "shield.blockedSubtitle"
    case shieldNoOpensLeft = "shield.noOpensLeft"
    case shieldOpenLimitSubtitle = "shield.openLimit.subtitle"
    case shieldOpenLimitJustBlockedSubtitle = "shield.openLimitJustBlocked.subtitle"
    case shieldOpenButtonOne = "shield.openButtonOne"
    case shieldOpenButtonMany = "shield.openButtonMany"
    case shieldPrimaryButtonLabel = "shield.primaryButtonLabel"

    // MARK: - LimitWarningDecision
    case notificationTimeLimitWarningTitle = "notification.timeLimitWarningTitle"
    case notificationTimeLimitWarningBodyFormat = "notification.timeLimitWarningBodyFormat"

    // MARK: - UsageReportFormatter + RuleUsageReport
    case usageReportNoUsageToday = "usageReport.noUsageToday"
    case usageReportTodayTotalFormat = "usageReport.todayTotalFormat"
    case usageReportDurationHoursMinutesFormat = "usageReport.durationHoursMinutesFormat"
    case usageReportDurationHoursFormat = "usageReport.durationHoursFormat"
    case usageReportDurationMinutesFormat = "usageReport.durationMinutesFormat"
    case usageReportUnderAMinute = "usageReport.underAMinute"
    case usageReportUnknownAppName = "usageReport.unknownAppName"

    // MARK: - RuleKind stragglers
    case ruleKindDefaultNameSchedule = "ruleKind.defaultNameSchedule"
    case ruleKindDefaultNameTimeLimit = "ruleKind.defaultNameTimeLimit"
    case ruleKindDefaultNameOpenLimit = "ruleKind.defaultNameOpenLimit"
    case selectionModeBlock = "selectionMode.block"
    case selectionModeAllowOnly = "selectionMode.allowOnly"


    // MARK: - ScreenTimeAccessRequiredView
    case screenTimeAccessTitle = "screenTimeAccess.title"
    case screenTimeAccessDescription = "screenTimeAccess.description"
    case screenTimeAccessOpenSettingsButton = "screenTimeAccess.openSettingsButton"

    /// Localized resource — the dedicated `Copy` table (`Shared/Copy.xcstrings`),
    /// `.main` bundle. A non-default table keeps our hand-authored symbolic keys
    /// isolated from Xcode's build-time string extraction, which only ever writes
    /// literal `Text("…")` strings to the default `Localizable` table. The catalog
    /// is embedded in every target, so `.main` resolves per process.
    var resource: LocalizedStringResource { LocalizedStringResource(String.LocalizationValue(rawValue), table: "Copy") }

    /// Resolved String for non-SwiftUI producers (shields, notifications, logic).
    var string: String { String(localized: resource) }

    /// Resolved + formatted for interpolated copy (placeholders live in the catalog value).
    func string(_ args: CVarArg...) -> String { String(format: string, arguments: args) }
}
