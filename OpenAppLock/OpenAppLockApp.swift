//
//  OpenAppLockApp.swift
//  OpenAppLock
//
//  Created by Brendan Chen on 2025.08.09.
//

import SwiftData
import SwiftUI

@main
struct OpenAppLockApp: App {
    @UIApplicationDelegateAdaptor(CustomAppDelegate.self) private var delegate
    
    private let container: ModelContainer?
    private let launchSettleDelay: Duration
    @State private var authorization: ScreenTimeAuthorization
    @State private var notificationAuthorization: NotificationAuthorization
    @State private var enforcer: RuleEnforcer
    @State private var settings: AppSettingsStore
    @State private var logStore: LogStore
    @State private var focus: FocusController
    @State private var conversation: ConversationCoordinator

    init() {
        let config = LaunchConfiguration.current
        #if DEBUG
        if !config.isUITesting, ProcessInfo.processInfo.arguments.contains("-export-conversation-support"),
           let group = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier),
           let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            do { try ConversationSupportExport.export(group: group, destination: documents.appendingPathComponent("VolitionSupport")) }
            catch { Diag.error(.conversation, "///CONVO-LOG support_export.failed") }
        }
        #endif

        // UI tests must not sit through the cold-launch settle window.
        launchSettleDelay = config.isUITesting ? .zero : RootView.defaultLaunchSettleDelay

        // Diagnostic logging, configured before anything else can log: app-group
        // `Logs/` in production; a wiped per-launch temp dir under UI testing so
        // the export flow is hermetic and deterministic.
        let logsDirectory: URL
        if config.isUITesting {
            let temp = FileManager.default.temporaryDirectory
                .appendingPathComponent("DiagLogsUITest", isDirectory: true)
            try? FileManager.default.removeItem(at: temp)
            logsDirectory = temp
        } else {
            logsDirectory = DiagnosticLogLocation.defaultDirectory()
        }
        Diag.configure(directory: logsDirectory)
        let logStore = LogStore(directory: logsDirectory)
        if !config.isUITesting {
            logStore.prune()
        }
        _logStore = State(initialValue: logStore)
        Diag.log(.lifecycle, "app launch (uiTesting=\(config.isUITesting))")
        if config.seedLogs {
            Diag.log(.rule, "SEED-MARKER seeded rule snapshot")
            Diag.log(.enforcer, .event, "SEED-MARKER refresh applied a shield")
            Diag.error(.monitor, "SEED-MARKER simulated threshold drop")
        }

        if let onboardingCompleted = config.onboardingCompleted {
            UserDefaults.standard.set(onboardingCompleted, forKey: "hasCompletedOnboarding")
        }

        // The app-group suite persists across UI-test launches (unlike the
        // in-memory SwiftData store), so start each UI-test run from a clean
        // Uninstall Protection state.
        if config.isUITesting {
            AppSettingsStore.resetForTesting()
        }
        let appSettings = AppSettingsStore()
        _settings = State(initialValue: appSettings)

        let schema = Schema(versionedSchema: OpenAppLockSchemaV5.self)
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: config.isUITesting
        )
        do {
            container = try ModelContainer(
                for: schema,
                migrationPlan: OpenAppLockSchemaMigrationPlan.self,
                configurations: [modelConfiguration]
            )
        } catch {
            container = nil
            Diag.error(.migration, "model storage unavailable; preserving saved store")
        }

        let accessURL: URL?
        if config.isUITesting {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("conversation-" + UUID().uuidString)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            accessURL = directory.appendingPathComponent("access.json")
        } else { accessURL = ConversationGrantStore().fileURL }
        let conversationStore = ConversationGrantStore(fileURL: accessURL)

        let usageLedger: UsageReading = config.isUITesting ? MockUsageLedger() : UsageLedger()

        if let scenario = config.seedScenario, let container {
            SampleRules.seed(
                scenario, into: container.mainContext, usage: usageLedger as? MockUsageLedger
            )
        }

        let authProvider: AuthorizationProviding =
            config.isUITesting
            ? MockAuthorizationProvider(
                status: config.onboardingCompleted == false
                    ? .notDetermined
                    : (config.screenTimeAccessRevoked ? .denied : .approved)
            )
            : FamilyControlsAuthorizationProvider()
        _authorization = State(initialValue: ScreenTimeAuthorization(provider: authProvider))

        let notificationProvider: NotificationAuthorizationProviding =
            config.isUITesting
            ? MockNotificationAuthorizationProvider(
                status: config.notificationsAuthorized ? .authorized : .notDetermined)
            : UserNotificationAuthorizationProvider()
        _notificationAuthorization = State(
            initialValue: NotificationAuthorization(
                provider: notificationProvider,
                initialStatus: config.isUITesting && config.notificationsAuthorized
                    ? .authorized : .notDetermined))

        let shields: ShieldApplying =
            config.isUITesting ? MockShieldController() : ManagedSettingsShieldController()
        let scheduler =
            config.isUITesting
            ? nil : RuleScheduler(monitor: DeviceActivityCenterMonitor())
        // Like the DeviceActivity scheduler, the notification scheduler is real
        // only outside UI tests (which must not schedule system notifications).
        let notificationScheduler = config.isUITesting ? nil : NotificationScheduler()
        let openSessions: OpenSessionReading =
            config.isUITesting ? MockOpenSessionStore() : OpenSessionStore()
        _enforcer = State(
            initialValue: RuleEnforcer(
                shields: shields, usage: usageLedger, scheduler: scheduler,
                notificationScheduler: notificationScheduler,
                openSessions: openSessions, settings: appSettings, conversationStore: conversationStore))
        _focus = State(initialValue: FocusController(access: ConversationEnforcement(store: conversationStore, shields: shields),
            monitor: config.isUITesting ? MockFocusMonitor() : DeviceFocusMonitor()))
        let coachService: (any CoachService)?
        #if DEBUG
        coachService = nil
        #else
        coachService = UnavailableCoachService()
        #endif
        let historyStore: any ConversationHistoryStoring
        if let container { historyStore = ConversationHistoryStore(context: container.mainContext) }
        else { historyStore = UnavailableHistoryStore() }
        let preferences = config.isUITesting ? CoachPreferences.testing() : CoachPreferences()
        if config.isUITesting, ProcessInfo.processInfo.arguments.contains("-ai-consent-required") { preferences.setConsent(false) }
        let client: any ConversationClient = config.isUITesting ? MockConversationClient(
            delay: ProcessInfo.processInfo.arguments.contains("-slow-coach") ? .seconds(15) : .zero,
            fails: ProcessInfo.processInfo.arguments.contains("-failing-coach")) : OpenAIConversationClient()
        let timer: any ConversationTimerScheduling = config.isUITesting ? MockConversationTimer() : DeviceConversationTimer()
        let checkInRoll: @Sendable () -> Bool
        if config.isUITesting { checkInRoll = { true } }
        else { checkInRoll = { Bool.random() } }
        _conversation = State(initialValue: ConversationCoordinator(historyStore: historyStore,
            preferences: preferences, service: coachService,
            client: client,
            keys: config.isUITesting ? MockConversationKeyStore() : ConversationEnvironmentKeyStore(),
            access: ConversationEnforcement(store: conversationStore, shields: shields),
            timer: timer, checkInRoll: checkInRoll))
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let container {
                    RootView(launchSettleDelay: launchSettleDelay).modelContainer(container)
                } else {
                    ContentUnavailableView {
                        Label(CopyKey.conversationStorageError.resource, systemImage: "externaldrive.badge.exclamationmark")
                    } description: { Text(CopyKey.storageRestartHelp.resource) }
                }
            }
                .modifier(UITestPresentation())
                .environment(authorization)
                .environment(notificationAuthorization)
                .environment(enforcer)
                .environment(settings)
                .environment(logStore)
                .environment(conversation)
                .environment(focus)
        }
    }
}
