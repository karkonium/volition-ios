export const strings = {
  "reflection.delayTitle": "Delay",
  "reflection.dealTitle": "Deal",
  "reflection.openTitle": "Skip / Open",
  "interface.uiSelectedAppUsageHelp":
    "Confirmed unlocks and minutes granted today for this app, not measured screen time.",
  "interface.uiProfileStep": "3. Set your intention",
  "interface.uiNameExplanation":
    "Apple lets Volition show the app you picked, but keeps its name private. Type the same name here so your coach knows which app you mean when you chat.",
  "interface.uiNameExplanationTitle": "Why copy the name?",
  "interface.uiSelectOne": "Select one",
  "interface.uiSelectedAppUsage": "Unlocks today: %lld · %lld min granted",
  "reflection.choiceHelp":
    "Only Deal creates a break afterward. Ending access early doesn’t shorten that break.",
  "reflection.customEmotionAction": "Add my own emotion",
  "reflection.customEmotionPlaceholder": "How are you feeling?",
  "reflection.customEmotionSubmit": "Continue",
  "reflection.customEmotionHelp": "A few words, up to 160 characters.",
  "conversation.feedbackQuestion": "How did you find this experience?",
  "conversation.feedbackHelpful": "Helpful",
  "conversation.feedbackNeutral": "Neutral",
  "conversation.feedbackAnnoying": "Annoying",
  "conversation.feedbackThanks": "Thanks for the feedback.",
  "reflection.openChoice": "%d minutes of access",
  "interface.appNameRequired": "Enter the name of the app you selected.",
  "activity.activityAlreadyUnlocked": "Already unlocked",
  "activity.activityAsked": "Question asked",
  "activity.activityBlockedByWait": "Access still declined",
  "activity.activityCancelled": "Request cancelled",
  "activity.activityClear": "Clear activity log",
  "activity.activityClearHelp":
    "This removes activity log entries and generated exports. Saved apps, coaching history and active waits stay in place.",
  "activity.activityDenied": "Access declined",
  "activity.activityEmpty":
    "Your requests and their outcomes will appear here.",
  "activity.activityExport": "Export activity log",
  "activity.activityExportError":
    "The activity log could not be exported. Please try again.",
  "activity.activityExportJSONL": "JSON Lines (.jsonl)",
  "activity.activityExportText": "Readable text (.txt)",
  "activity.activityFailed": "Request failed",
  "activity.activityInterrupted": "Request interrupted",
  "activity.activityInterruptedHelp":
    "The request was interrupted before its result was recorded.",
  "activity.activityLogTitle": "Activity log",
  "activity.activityNoApp": "No app selected",
  "activity.activityPending": "Awaiting response",
  "activity.activityPrivacy":
    "This local log contains your messages and coach replies. Recent access outcomes and conversation context are shared with OpenAI only while AI coaching is enabled. Exports share the records you choose.",
  "activity.activitySelectionRequired": "App selection needed",
  "activity.activityUnconfirmed": "Unlock unconfirmed",
  "activity.activityUnlocked": "Unlocked",
  "activity.activityWait": "Declined for now",
  "activity.conversationAmbiguousApp":
    "You mentioned more than one saved app. Choose which one above, then send again.",
  "activity.conversationSelectAppHelp":
    "Choose an app above, or type its saved name in your message.",
  "conversation.approvalOne": "Approved for 1 minute.",
  "conversation.conversationApprovalMarker": "Approved for %lld minutes.",
  "conversation.conversationAppsValidation":
    "Choose an app list containing individual apps only. Categories and websites are not supported.",
  "conversation.conversationAuthenticationError":
    "OpenAI rejected the API key (401). Update OpenAppLock/Conversation.env and rebuild. Your app stays blocked.",
  "conversation.conversationBlockedStatus": "Conversation required",
  "conversation.conversationCancel": "Cancel",
  "conversation.conversationChatHere": "Chat here",
  "conversation.conversationChatTitle": "Chat",
  "conversation.conversationChooseApp": "Choose an app",
  "conversation.conversationContinueInVolition": "Continue in Volition",
  "conversation.conversationDefaultName": "Intentional Access",
  "conversation.conversationDiagnosticsDisabled": "Conversation logs disabled",
  "conversation.conversationDiagnosticsEnabled": "Conversation logs enabled",
  "conversation.conversationDiagnosticsHelp":
    "Filter Xcode Console or exported diagnostic logs for ///CONVO-LOG. Set CONVO_LOG_ENABLED=0 in the env file and rebuild to disable.",
  "conversation.conversationDirectRequestInstructions":
    "Tap Request access to open chat in Volition. If it doesn’t open, open Volition directly.",
  "conversation.conversationEnableNotifications": "Enable chat notifications",
  "conversation.conversationEndUnlock": "End unlock",
  "conversation.conversationEnvironmentConfigured": "Configured at build time",
  "conversation.conversationEnvironmentHelp":
    "Set OPENAI_API_KEY in OpenAppLock/Conversation.env on your Mac, then rebuild and install the app. Previously saved in-app keys are no longer used.",
  "conversation.conversationEnvironmentMissing": "No key in this build",
  "conversation.conversationGoalValidation":
    "Write a goal of 1–2,000 characters.",
  "conversation.conversationGrantActive":
    "This app is already unlocked. Its original timer keeps running; you can keep chatting or choose another app.",
  "conversation.conversationGrantEnded": "Unlock ended.",
  "conversation.conversationGrantExpired": "Unlock expired.",
  "conversation.conversationGrantFailed":
    "Access was approved, but the unlock could not start. The app stays blocked. Retry when monitoring is available.",
  "conversation.conversationHistoryClear": "Clear conversation history",
  "conversation.conversationMessagePrompt": "Why do you want access?",
  "conversation.conversationMissingKey":
    "Set OPENAI_API_KEY in OpenAppLock/Conversation.env, then rebuild and reinstall the app.",
  "conversation.conversationNetworkError":
    "Could not reach OpenAI. Check your connection, then retry. Your app stays blocked.",
  "conversation.conversationNotificationBody":
    "Tap to talk with Volition about your access request.",
  "conversation.conversationNotificationHelp":
    "Enable notifications for access reminders at 1 minute, 30 seconds and 10 seconds remaining. Older iOS versions also use notifications to open Chat. iOS may silence or delay alerts.",
  "conversation.conversationNotificationInstructions":
    "Tap the “Chat here” notification to continue. If you don’t see it, enable notifications for Volition in Settings. You can always open Volition directly. Tap Request access to try again.",
  "conversation.conversationNotificationSettings": "Notification settings",
  "conversation.conversationPermissionError":
    "OpenAI denied access (403). Check the API project and model permissions. Your app stays blocked.",
  "conversation.conversationQuotaError":
    "OpenAI API quota is exhausted (429). Check API billing and project limits, then retry. Your app stays blocked.",
  "conversation.conversationRateLimitError":
    "OpenAI rate limited this request (429). Wait a moment, then retry. Your app stays blocked.",
  "conversation.conversationRequestAccess": "Request access",
  "conversation.conversationRequestError":
    "OpenAI rejected the request or model. Check ///CONVO-LOG for the HTTP status and error code. Your app stays blocked.",
  "conversation.conversationRequestInstructions":
    "Tap Request access for a notification that takes you to chat. You can also open Volition directly.",
  "conversation.conversationRequestMarker": "Request: %@",
  "conversation.conversationResponseError":
    "The coach could not finish a valid reply. Please try again. Your app stays blocked.",
  "conversation.conversationRuleExample": "Talk through why you want access.",
  "conversation.conversationRuleTitle": "Conversation",
  "conversation.conversationSend": "Send",
  "conversation.conversationServiceError":
    "OpenAI returned a service error. Retry shortly and check ///CONVO-LOG for details. Your app stays blocked.",
  "conversation.conversationStaleRequest":
    "The rules or requested app changed. Choose the app again to continue.",
  "conversation.conversationStorageError":
    "Conversation storage is unavailable. Please try again.",
  "conversation.conversationTargetGeneric": "Selected app",
  "conversation.conversationUnlockedUntil": "Unlocked until %@",
  "conversation.conversationWaiting": "Thinking…",
  "conversation.dealAccept": "Accept deal",
  "conversation.dealAccepted":
    "Deal accepted. %@ is unlocked for %lld minutes.",
  "conversation.dealBlockedUntil": "Agreed break until %@",
  "conversation.dealDecline": "Decline",
  "conversation.dealDeclined": "Deal declined. The app stays blocked.",
  "conversation.dealHelp":
    "The break starts when access ends and lasts until the agreed time, even if you end access early.",
  "conversation.dealOffered": "Deal offered",
  "conversation.dealTerms": "Unlock %@ for %@, then keep it blocked for %@.",
  "conversation.openManually": "Open Volition to talk through your request.",
  "conversation.pauseProposal":
    "Before making a deal, let’s try a pause before opening. How long do you think you could wait?",
  "conversation.sessionCounts": "Today’s unlocks: %lld short · %lld longer",
  "conversation.sessionCountsHelp":
    "For this app. Short: 1–5 minutes; longer: 6–60. Counts unlocks granted, not time spent.",
  "conversation.unlockActivityExpired": "Access window ended",
  "conversation.unlockActivityWindow":
    "Access window · finish before the timer ends",
  "conversation.unlockReminderMinute":
    "1 minute left in your access window. Time to wrap up.",
  "conversation.unlockReminderSeconds":
    "%lld seconds left in your access window. Finish up and step away.",
  "conversation.unlockReminderTitle": "%@ · wrapping up",
  "diagnostics.cancelButton": "Cancel",
  "diagnostics.clearAllLogsButton": "Clear All Logs",
  "diagnostics.clearLogsConfirmationMessage":
    "This permanently deletes all recorded diagnostic logs on this device.",
  "diagnostics.clearLogsConfirmationTitle": "Clear all logs?",
  "diagnostics.daysSectionFooter":
    "Logs stay on-device and do not include information about which apps are blocked.",
  "diagnostics.daysSectionHeader": "Days",
  "diagnostics.navigationTitle": "Logs",
  "diagnostics.noEntriesPlaceholder": "No entries.",
  "diagnostics.noLogsMessage":
    "No logs yet. Logs are recorded automatically as rules enforce.",
  "expansion.aiConsentAccept": "Allow AI coaching",
  "expansion.aiConsentDisclosure":
    "When you chat, Volition sends your messages, saved app names and intentions, conversation memory, and recent access outcomes to OpenAI to respond. App selection tokens stay on this device. History is saved locally; exported files contain your messages and replies.",
  "expansion.aiConsentLater": "Set up without AI for now",
  "expansion.aiConsentRequired":
    "Allow AI coaching before sending a message. You can review what is shared in Privacy & Data.",
  "expansion.aiConsentTitle": "Your conversation, your choice",
  "expansion.aiConsentToggle": "Allow sharing for AI coaching",
  "expansion.aiConsentWithdrawal":
    "AI coaching is optional. You can withdraw permission in Privacy & Data at any time. Withdrawing stops new requests and cancels a pending reply; it does not undo data already transmitted or lift existing restrictions.",
  "expansion.appConversationProtected": "Conversation protected",
  "expansion.appTemporarilyOpen": "Temporarily open",
  "expansion.chatLoadEarlier": "Load earlier messages",
  "expansion.coachReady": "The coach is ready.",
  "expansion.coachTone": "Coaching tone",
  "expansion.coachToneHelp":
    "Choose how the coach speaks. Access limits, waits, and focus protection stay the same.",
  "expansion.coachUnavailable":
    "The coach is unavailable in this build. Your apps remain protected. You can still manage your restrictions in Apps.",
  "expansion.enforcementRecovered":
    "Protection was restored after a storage problem. Please retry to refresh its status.",
  "expansion.enforcementUncertain":
    "Protection could not be verified. Existing restrictions were preserved. Please retry.",
  "expansion.eraseCoachingContent": "Erase coaching content",
  "expansion.eraseCoachingHelp":
    "Erase conversations, coaching memory, activity records, request reasons, replies, and local activity exports. Saved app intentions remain. Active access and waiting deadlines keep their original times.",
  "expansion.focusActiveSession": "Focusing now",
  "expansion.focusAddSchedule": "Add protected period",
  "expansion.focusAllApps": "Protect all saved apps",
  "expansion.focusCustomDuration": "Custom duration",
  "expansion.focusDays": "Days",
  "expansion.focusDuration": "Duration",
  "expansion.focusEnabled": "Enabled",
  "expansion.focusEndCurrent": "End current protection",
  "expansion.focusEndHelp":
    "End the current session and skip any protected period active now. Future scheduled periods remain enabled. Apps return to ordinary conversation protection.",
  "expansion.focusEnds": "Ends",
  "expansion.focusHelp":
    "Make room for what matters. During protected periods, the coach cannot grant access to the selected apps. Outside those periods, your saved apps still require a conversation.",
  "expansion.focusProtected":
    "Focus protection is active. Access stays closed until it ends.",
  "expansion.focusRemoveSchedule": "Remove schedule",
  "expansion.focusSaveError":
    "Focus protection could not be updated. Existing restrictions were kept. Try again when monitoring is available.",
  "expansion.focusScheduleHelp":
    "Choose a period of at least 15 minutes. An end time earlier than the start continues into the next day.",
  "expansion.focusScheduleName": "Name",
  "expansion.focusSchedules": "Recurring protection",
  "expansion.focusStart": "Start focus",
  "expansion.focusStartSession": "Start a focus session",
  "expansion.focusStarts": "Starts",
  "expansion.focusTitle": "Focus",
  "expansion.insightsByApp": "By app",
  "expansion.insightsDailyRequests": "Requests by day",
  "expansion.insightsDay": "Day",
  "expansion.insightsDenials": "Declined",
  "expansion.insightsEarlyEndings": "Ended early",
  "expansion.insightsEmpty":
    "Your access trends will appear here after you chat.",
  "expansion.insightsGrants": "Confirmed grants",
  "expansion.insightsHelp":
    "These are access opportunities, not measured screen time. Granted minutes describe permission to use an app; they do not prove the app was used.",
  "expansion.insightsMinutes": "Granted minutes",
  "expansion.insightsOpportunities": "Access opportunities",
  "expansion.insightsRange": "Date range",
  "expansion.insightsRequests": "Requests",
  "expansion.insightsTitle": "Insights",
  "expansion.insightsToday": "Today",
  "expansion.insightsWaits": "Pauses suggested",
  "expansion.insightsWeek": "Last 7 days",
  "expansion.privacyPolicy": "Privacy policy",
  "expansion.privacyPolicyPending":
    "A public privacy policy is not yet available. Review the data-sharing explanation above before enabling AI coaching.",
  "expansion.privacyTitle": "Privacy & Data",
  "expansion.storageRestartHelp":
    "Saved data could not be opened. Close and reopen Volition to retry. Your data has not been reset.",
  "expansion.toneBalanced": "Balanced",
  "expansion.toneDirect": "Direct",
  "expansion.toneWarm": "Warm",
  "interface.uiAISharingHelp":
    "Review what is shared before you start a conversation.",
  "interface.uiAISharingOff": "AI coaching is off",
  "interface.uiAccessDetail":
    "An approval gives you a short window. Then protection returns.",
  "interface.uiAccessStep": "Open with intention",
  "interface.uiActivitySubtitle": "Requests, replies and access outcomes",
  "interface.uiAppInsights": "%d grants · %d minutes allowed",
  "interface.uiApproved": "Access approved",
  "interface.uiAppsIntro": "A clear intention for every app you open.",
  "interface.uiAsked": "Let’s talk it through",
  "interface.uiBack": "Back",
  "interface.uiCancelledDraft":
    "Request cancelled. Your draft is ready to edit.",
  "interface.uiChangeApp": "Change app",
  "interface.uiChatIntro":
    "Name what you need and how long you need it. We’ll take it one opening at a time.",
  "interface.uiChooseDetail": "Protect the apps you tend to open on autopilot.",
  "interface.uiChooseStep": "Choose your apps",
  "interface.uiCoachName": "Volition",
  "interface.uiCoachSubtitle": "Tone and conversation history",
  "interface.uiConversationDetail":
    "Tell your coach what you need and how long you need it.",
  "interface.uiConversationHistory": "Conversation history",
  "interface.uiConversationStep": "Talk it through",
  "interface.uiDataControls": "Data controls",
  "interface.uiDenied": "Not approved",
  "interface.uiDiagnosticsSubtitle": "Troubleshooting and exports",
  "interface.uiErasureDetails": "What gets erased?",
  "interface.uiFocusIntro": "A little space from the apps that pull you away.",
  "interface.uiFocusScheduleEmpty":
    "Set a regular time for fewer distractions.",
  "interface.uiFocusStatus": "Protected by Focus",
  "interface.uiHistorySupport": "History & support",
  "interface.uiHowItWorks": "A little space before you open.",
  "interface.uiIntentionStep": "4. Additional information",
  "interface.uiLatestMessages": "Latest messages",
  "interface.uiLocalDataDetail":
    "Apple’s app-selection tokens stay here. Chat and activity history are saved locally; exported files contain your messages and replies.",
  "interface.uiLocalDataTitle": "Kept on this device",
  "interface.uiMinutes": "%d min",
  "interface.uiNameStep": "2. Copy the app name",
  "interface.uiPeriodEditorTitle": "Protected period",
  "interface.uiPermissionStep": "Screen Time",
  "interface.uiPermissions": "Permissions",
  "interface.uiPermissionsHelp":
    "Screen Time permission lets Volition protect your chosen apps. Permission alone does not confirm that a restriction is currently active.",
  "interface.uiPickerEmpty": "No saved apps yet",
  "interface.uiPickerEmptyHelp":
    "Add an app and an intention to start a conversation.",
  "interface.uiPickerGuidanceDetail":
    "Open a category or use search, then tap an individual app. Your choice returns here automatically.",
  "interface.uiPickerGuidanceTitle": "One app at a time",
  "interface.uiPickerIntro":
    "Choose an app to talk about. Your conversation and draft stay with you.",
  "interface.uiPreferences": "Preferences",
  "interface.uiPrivacyStep": "Your privacy",
  "interface.uiPrivacySubtitle": "AI permission and your data",
  "interface.uiRequestFailed": "Couldn’t complete this request",
  "interface.uiRequestFor": "Request access to",
  "interface.uiRetry": "Try again",
  "interface.uiReviewSharing": "Review AI sharing",
  "interface.uiSave": "Save",
  "interface.uiSavedApps": "Your apps",
  "interface.uiScreenTimeOff": "Screen Time access needed",
  "interface.uiScreenTimeOn": "Screen Time access enabled",
  "interface.uiSearchApps": "Search your apps",
  "interface.uiSearchEmpty": "No matching apps",
  "interface.uiSearchEmptyHelp":
    "Try another app name or a word from your intention.",
  "interface.uiSelectStep": "1. Choose an app",
  "interface.uiSelected": "Selected",
  "interface.uiSelectedApp": "Selected app",
  "interface.uiSending": "Thinking about your request…",
  "interface.uiServiceStatus": "Coach availability",
  "interface.uiSharedApps": "App names & intentions",
  "interface.uiSharedAppsDetail":
    "The names and intentions you save give your requests context.",
  "interface.uiSharedMessages": "Messages & memory",
  "interface.uiSharedMessagesDetail":
    "Messages, replies, conversation memory and app-removal feedback help the coach respond.",
  "interface.uiSharedOutcomes": "Recent access outcomes",
  "interface.uiSharedOutcomesDetail":
    "Requests, grants, pauses, optional check-in choices, deals and removal feedback help the coach understand recent choices.",
  "interface.uiSharedWithAI": "Shared with OpenAI",
  "interface.uiSharingDetails": "Sharing details",
  "interface.uiSystemSettings": "Open system settings",
  "interface.uiVoluntaryDetail":
    "Your restrictions are voluntary. You can deliberately change or remove them.",
  "interface.uiVoluntaryTitle": "You stay in control",
  "interface.uiWaiting": "Wait before access",
  "interface.uiWelcomeStep": "Welcome",
  "nav.appTitle": "Volition",
  "nav.settingsSectionTitle": "Settings",
  "notification.timeLimitWarningBodyFormat":
    "%@: %lld minutes of your time limit left.",
  "notification.timeLimitWarningTitle": "Time limit almost up",
  "onboarding.accessDeclinedMessage":
    "Screen Time access was declined. Volition can’t block apps without it.",
  "onboarding.activityStaysPrivateBullet":
    "Your app activity stays on this device and is never collected.",
  "onboarding.allowScreenTime": "Allow Screen Time Access",
  "onboarding.changeAnytimeBullet": "You can change this anytime in Settings.",
  "onboarding.continueButton": "Continue",
  "onboarding.openSettingsButton": "Open Settings",
  "onboarding.requesting": "Requesting…",
  "onboarding.screenTimeFrameworkBullet":
    "Volition uses Apple’s Screen Time framework to block the apps you choose.",
  "preset.balanceSectionSubtitle": "Make room for what matters.",
  "preset.balanceSectionTitle": "Healthy Balance",
  "preset.deepWorkName": "Deep Work",
  "preset.eveningResetName": "Evening Reset",
  "preset.familyDinnerName": "Family Dinner",
  "preset.focusSectionSubtitle": "Protect your deep work hours.",
  "preset.focusSectionTitle": "Focus Time",
  "preset.lightsOutName": "Lights Out",
  "preset.morningFocusName": "Morning Focus",
  "preset.restSectionSubtitle": "Wind down on a schedule.",
  "preset.restSectionTitle": "Rest & Recharge",
  "preset.screenFreeSundayName": "Screen-Free Sunday",
  "reflection.conversationJumpLatest": "Latest messages",
  "reflection.profileBoth": "Both",
  "reflection.profileChange": "What would you like to change?",
  "reflection.profileCommunication": "Communication",
  "reflection.profileDefaultGoal":
    "Use this app intentionally, with room for work, connection and enjoyment.",
  "reflection.profileDistraction": "Using it when I mean to do something else",
  "reflection.profileDuration": "Spending longer than intended",
  "reflection.profileFrequency": "Using it too frequently",
  "reflection.profileHabit": "Opening it automatically or out of habit",
  "reflection.profileIntentional": "Just want to be more intentional",
  "reflection.profileLearning": "Learning or information",
  "reflection.profileLong": "Longer, intentional sessions",
  "reflection.profileNotes": "Anything else?",
  "reflection.profileNotesHelp":
    "For example: mostly afternoons, work use, fewer long scrolling sessions. Add any goals or boundaries.",
  "reflection.profileOptional":
    "Choose what fits, or leave these for later. You can always edit them.",
  "reflection.profileOther": "Other",
  "reflection.profileProductivity": "Work or productivity",
  "reflection.endDelay": "End delay",
  "reflection.unlock": "Unlock for %lld minutes",
  "reflection.delayHelp":
    "The app stays locked until you choose to unlock it. Checking in is optional.",
  "reflection.choiceTitle": "What would help this time?",
  "reflection.delayChoice": "%lld seconds, then %lld minutes",
  "reflection.dealChoice": "%lld minutes now, then %lld minutes blocked",
  "reflection.profilePurpose": "What do you want to use this app for?",
  "reflection.profileRelaxation": "Entertainment or relaxation",
  "reflection.profileSelectMultiple": "Select multiple",
  "reflection.profileShort": "Occasional short visits",
  "reflection.profileStyle": "What would good usage look like?",
  "reflection.profileTiming": "Using it at certain times",
  "reflection.profileUnsure": "Not sure yet",
  "reflection.reflectionAnswerHelp":
    "Choose an option to continue. Not sure / Skip is fine, too.",
  "reflection.reflectionAnxiety": "Anxiety",
  "reflection.reflectionAvoidance": "Avoiding something",
  "reflection.reflectionBoredom": "Boredom",
  "reflection.reflectionCancel": "Keep app closed",
  "reflection.reflectionCancelled": "Pause cancelled; app stays closed.",
  "reflection.reflectionCompleted":
    "Pause complete. %@ is unlocked for %ld minutes.",
  "reflection.reflectionExpired":
    "This pause is no longer current. Send a new request when you’re ready.",
  "reflection.reflectionHelp":
    "An optional check-in. You don’t need to share a feeling to continue.",
  "reflection.reflectionLoneliness": "Loneliness",
  "reflection.reflectionLongPlan":
    "Pause for %@ before opening. Start when you’re ready, or keep it locked.",
  "reflection.reflectionNotSure": "Not sure / Skip",
  "reflection.reflectionOffer": "Pause before opening",
  "reflection.reflectionOpening": "Opening app…",
  "reflection.reflectionOther": "Something else",
  "reflection.reflectionPlan": "%@ · %ld-minute unlock afterward",
  "reflection.reflectionQuestion": "What’s pulling you here right now?",
  "reflection.reflectionReady": "Ready when you are",
  "reflection.reflectionRecorded": "Pause before opening",
  "reflection.reflectionRelaxation": "Just want to relax",
  "reflection.reflectionSkip": "Skip pause & open app",
  "reflection.reflectionStart": "Start pause",
  "reflection.reflectionStress": "Stress",
  "reflection.reflectionTaking": "Pausing before opening",
  "removal.removalAlternative": "Would a temporary unlock help instead?",
  "removal.removalAlternativeHelp":
    "You can ask the coach for a short unlock, keep your current setup, or remove the app. Existing agreements still apply to unlock requests.",
  "removal.removalAnyway": "Remove app anyway",
  "removal.removalAsk": "Ask for %lld minutes instead",
  "removal.removalCompleted": "Removed this app from Volition.",
  "removal.removalContinue": "Continue",
  "removal.removalFeedbackTitle": "High frustration · app removal",
  "removal.removalIntentRecorded":
    "User is considering removing this app from Volition.",
  "removal.removalKeep": "Keep this app",
  "removal.removalKept": "Kept this app in Volition.",
  "removal.removalMinutes": "Minutes: %lld",
  "removal.removalReason": "Your reason",
  "removal.removalRequestMessage":
    "I was considering removing this app because: %@. Would you unlock it for %lld minutes instead?",
  "removal.removalTemporaryRequested":
    "Kept this app and requested %lld minutes instead. Access still requires coach approval.",
  "removal.removalWhy": "What is making you want to remove this app?",
  "removal.removalWhyHelp":
    "Tell us what feels frustrating or is getting in your way. This stays in your private activity log.",
  "ruleDetail.appListSummaryFormat": "%@ · %@",
  "ruleDetail.noAppsPlaceholder": "No apps",
  "ruleDraft.validationStartEndTimesTooCloseMessage":
    "Due to system limitations, the start and end times must be at least 15 minutes apart.",
  "ruleDraft.validationStartEndTimesTooCloseToMidnightMessage":
    "Due to system limitations, the start time can’t be within 15 minutes to midnight.",
  "ruleEditor.appListMultipleSummaryFormat": "%1$d Lists · %2$d Apps",
  "ruleKind.defaultNameOpenLimit": "Gate Keeper",
  "ruleKind.defaultNameSchedule": "In the Zone",
  "ruleKind.defaultNameTimeLimit": "Time Keeper",
  "ruleKind.openLimitDisplayName": "Open Limit",
  "ruleKind.openLimitExampleText": "e.g. 5 opens/day",
  "ruleKind.scheduleDisplayName": "Schedule",
  "ruleKind.scheduleExampleText": "e.g. 9-5, Daily",
  "ruleKind.timeLimitDisplayName": "Time Limit",
  "ruleKind.timeLimitExampleText": "e.g. 45m/day",
  "screenTimeAccess.description":
    "Volition can’t block anything without Screen Time access. Turn it back on in Settings to keep your chosen apps protected.",
  "screenTimeAccess.openSettingsButton": "Open Settings",
  "screenTimeAccess.title": "Screen Time Access Needed",
  "selectionMode.allowOnly": "Allow only",
  "selectionMode.block": "Block",
  "settings.logsRowLabel": "Logs",
  "settings.navigationTitle": "Settings",
  "shield.blockedSubtitle": "This app is blocked by Volition.",
  "shield.blockedTitle": "App Blocked",
  "shield.noOpensLeft": "No opens left today — the block lifts tomorrow.",
  "shield.openButtonMany": "Open (%lld left)",
  "shield.openButtonOne": "Open (1 left)",
  "shield.openLimit.subtitle":
    "Opened %lld of %lld times today. Each open lasts %lld minutes.",
  "shield.openLimitJustBlocked.subtitle":
    "You just used an open for this app list. You may use another open later.",
  "shield.primaryButtonLabel": "OK",
  "status.activeLeft": "Ends in %@",
  "status.countdownDays": "%lldd",
  "status.countdownHours": "%lldh",
  "status.countdownMinutes": "%lldm",
  "status.disabled": "Disabled",
  "status.noDaysSelected": "No days selected",
  "status.resetsIn": "Resets in %@",
  "status.resumesIn": "Resumes in %@",
  "status.startsIn": "Starts in %@",
  "usage.subtitleSeparator": "%@ · %@",
  "usageReport.durationHoursFormat": "%lldh",
  "usageReport.durationHoursMinutesFormat": "%lldh %lldm",
  "usageReport.durationMinutesFormat": "%lldm",
  "usageReport.noUsageToday": "No usage today",
  "usageReport.todayTotalFormat": "%@ today",
  "usageReport.underAMinute": "<1m",
  "usageReport.unknownAppName": "Unknown",
  "volition.volitionAccessHistory":
    "Your coach remembers recent requests and unlocks across apps to help you spot patterns.",
  "volition.volitionAddApp": "Add an app",
  "volition.volitionAppName": "App name",
  "volition.volitionAppNameHelp":
    "Enter the same name as the app you selected above—for example, SoundCloud.",
  "volition.volitionApps": "Apps",
  "volition.volitionAppsHelp":
    "These apps stay blocked until you chat with Volition. You choose the intention; your coach helps with the next step.",
  "volition.volitionChatEmpty": "What would you like to make time for?",
  "volition.volitionClearHelp":
    "Clear the chat messages and summary, and cancel pending pauses and deal offers? Saved app intentions, the activity log, coaching history and agreed breaks are kept.",
  "volition.volitionCoachSettings": "Your coach",
  "volition.volitionDuplicateError":
    "This app is already saved. Edit it in Apps.",
  "volition.volitionEditApp": "Your intention",
  "volition.volitionIntention": "How do you want to use this app?",
  "volition.volitionIntentionError":
    "Describe how you want to use this app (up to 2,000 characters).",
  "volition.volitionIntentionHelp":
    "For example: Stay in touch with close friends, without getting pulled into the feed.",
  "volition.volitionNameError": "Give this app a name (up to 100 characters).",
  "volition.volitionPickOneHelp":
    "Choose one individual app. The picker closes when you select it. Categories and websites aren’t supported.",
  "volition.volitionPrivacy":
    "Your app names, intentions, conversation and recent optional check-ins are sent to OpenAI when you chat. Your history is stored on this device.",
  "volition.volitionRemoveApp": "Remove app",
  "volition.volitionRemoveMessage":
    "Removing this app lifts its Volition restriction immediately and ends any active access for it. You can add it again later.",
  "volition.volitionRetry": "Try again",
  "volition.volitionSaveApp": "Save app",
  "volition.volitionSaveError": "Couldn’t save your changes. Please try again.",
  "volition.volitionSetupHelp":
    "Choose apps one at a time. Give each a name and an intention. Volition will help you pause and choose when to open them.",
  "volition.volitionSetupTitle": "Choose your apps",
  "volition.volitionSingleAppError":
    "Choose exactly one app, without categories or websites.",
  "volition.volitionStartChat": "Start chatting",
  "volition.volitionWaitError":
    "No extra access yet. You can keep chatting or choose another app.",
  "volition.volitionWaitHelp":
    "This app is still blocked. The countdown is a waiting period, not an unlock. You can keep chatting or choose another app.",
  "volition.volitionWaiting": "Still blocked",
  "volition.volitionWelcome": "Welcome to Volition",
  "volition.volitionWelcomeDescription":
    "A little pause. A thoughtful conversation. More time for what matters to you.",
  "weekday.everyDaySummary": "Every day",
  "weekday.fridayAbbreviation": "Fri",
  "weekday.mondayAbbreviation": "Mon",
  "weekday.neverSummary": "Never",
  "weekday.saturdayAbbreviation": "Sat",
  "weekday.shortLabelF": "F",
  "weekday.shortLabelM": "M",
  "weekday.shortLabelS": "S",
  "weekday.shortLabelT": "T",
  "weekday.shortLabelW": "W",
  "weekday.sundayAbbreviation": "Sun",
  "weekday.thursdayAbbreviation": "Thu",
  "weekday.tuesdayAbbreviation": "Tue",
  "weekday.wednesdayAbbreviation": "Wed",
  "weekday.weekdaysSummary": "Weekdays",
  "weekday.weekendsSummary": "Weekends",
} as const;
