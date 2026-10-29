//
//  MainView.swift
//  OpenAppLock
//

import SwiftData
import SwiftUI

/// The post-permission shell first retires legacy rules and reconciles shields.
/// With no saved apps it requires per-app setup before exposing Chat.
/// The post-onboarding shell. Chooses its navigation chrome from the horizontal
/// size class — a bottom `TabView` (`MainTabView`) in compact width (iPhone, iPad
/// multitasking) and a left sidebar (`MainSidebarView`) in regular width
/// (full-screen iPad) — and owns the app-level enforcement lifecycle so it runs
/// regardless of which layout is showing and which section is selected.
/// Incoming app URLs return to Chat and reconcile the pending shield request.
///
/// The lifecycle is a 30 s `refresh` loop, a reconcile on any blocking-relevant
/// rule change, and a reconcile whenever the app becomes active (so Uninstall
/// Protection re-evaluates on every foreground).
struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ConversationCoordinator.self) private var conversation
    @Environment(NotificationAuthorization.self) private var notificationAuthorization
    @Environment(AppSettingsStore.self) private var settings
    @Environment(RuleEnforcer.self) private var enforcer
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query(sort: \BlockingRule.createdAt) private var rules: [BlockingRule]
    
    @State private var prepared = false
    @State private var needsSetup = false
    @State private var preparationError = false
    @State private var retry = UUID()
    // State remains current inside the long-lived loop, unlike its captured
    // view's initial Environment value when the scene changes in the meantime.
    @State private var sceneIsActive = false

    var body: some View {
        Group {
            if preparationError {
                ContentUnavailableView {
                    Label(CopyKey.volitionSaveError.resource, systemImage: "exclamationmark.triangle")
                } actions: {
                    Button(CopyKey.volitionRetry.resource) { retry = UUID() }
                }
            } else if !prepared { ProgressView() }
            else if needsSetup {
                VolitionAppsView { needsSetup = false; conversation.selectedSection = .chat }
            } else { layout }
        }
            .task(id: retry) {
                do {
                    preparationError = false
                    #if DEBUG
                    if !LaunchConfiguration.current.isUITesting { try ConversationTimerProbe.reset() }
                    #endif
                    try VolitionApps.prepare(in: modelContext)
                    settings.uninstallProtectionEnabled = false
                    settings.notifyScheduleStartEnabled = false
                    settings.notifyTimeLimitEndingEnabled = false
                    let current = try modelContext.fetch(FetchDescriptor<BlockingRule>())
                    needsSetup = !current.contains { $0.kind == .conversation && $0.isEnabled }
                    await enforcer.refresh(rules: current)
                    await conversation.refresh(snapshots: current.map(\.dto), consumeRequests: sceneIsActive)
                    prepared = true
                    if !LaunchConfiguration.current.isUITesting {
                        await notificationAuthorization.refresh()
                        if notificationAuthorization.status == .notDetermined { await notificationAuthorization.request() }
                    }
                } catch { preparationError = true; return }
                await enforcementLoop()
            }
            .onChange(of: ruleChangeToken) {
                // Logs the rule/app-list-driven refresh trigger so the timeline
                // shows whether (e.g.) an app-list edit re-enforced at all.
                Diag.log(.lifecycle, "refresh trigger: rule-change observed")
                refreshEnforcement()
            }
            .onChange(of: scenePhase, initial: true) { _, phase in
                sceneIsActive = phase == .active
                conversation.isForeground = sceneIsActive
                if phase == .active {
                    Diag.log(.lifecycle, "refresh trigger: scenePhase active")
                    refreshEnforcement()
                }
            }
            .task(id: "\(prepared)-\(sceneIsActive)-\(conversation.reflectionScheduleID)") {
                guard prepared, sceneIsActive else { return }
                while !Task.isCancelled {
                    await conversation.resumeReflections(snapshots: { rules.filter { !$0.isDeleted }.map(\.dto) })
                    guard !Task.isCancelled, let deadline = conversation.nextReflectionDeadline else { return }
                    do { try await Task.sleep(for: .seconds(max(0.05, deadline.timeIntervalSinceNow))) }
                    catch { return }
                }
            }
            .task(id: "presentation-\(prepared)-\(sceneIsActive)-\(conversation.presentationID)") {
                guard prepared, sceneIsActive else { return }
                await conversation.updateSessionPresentation()
            }
            .onDisappear { conversation.isForeground = false }
            .onOpenURL { url in
                Diag.log(.lifecycle, "handling URL open: coach")
                conversation.selectedSection = .chat
                conversation.openRequestURL(url, snapshots: rules.map(\.dto))
                refreshEnforcement()
            }
    }

    @ViewBuilder
    private var layout: some View {
        switch MainLayout.resolve(horizontalSizeClass: horizontalSizeClass) {
        case .tabs:
            MainTabView()
        case .sidebar:
            MainSidebarView()
        }
    }

    // MARK: - Enforcement

    /// Changes whenever any rule's blocking-relevant state changes.
    private var ruleChangeToken: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(rules.map(\.dto)))?.base64EncodedString() ?? ""
    }

    private func refreshEnforcement() {
        guard prepared else { return }
        // Enforcement I/O runs off the main thread inside the enforcer; this
        // fire-and-forget Task hands it the current rules and returns immediately.
        Task {
            await enforcer.refresh(rules: rules)
            await conversation.refresh(snapshots: rules.map(\.dto), consumeRequests: sceneIsActive)
        }
    }

    /// Keeps shields in sync while the app is open, so windows that begin or end
    /// while the user is looking at the screen take effect promptly.
    private func enforcementLoop() async {
        while !Task.isCancelled {
            let allRules = (try? modelContext.fetch(FetchDescriptor<BlockingRule>())) ?? []
            // The 30 s foreground backstop. Logged each tick so coverage gaps
            // (when the app isn't open to run this) are visible as timeline holes.
            Diag.log(.lifecycle, "refresh trigger: foreground 30s loop")
            await enforcer.refresh(rules: allRules)
            await conversation.refresh(snapshots: allRules.map(\.dto), consumeRequests: sceneIsActive)
            try? await Task.sleep(for: .seconds(30))
        }
    }
}
