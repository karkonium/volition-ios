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
    @Environment(FocusController.self) private var focus
    @Environment(ConversationCoordinator.self) private var conversation
    @Environment(NotificationAuthorization.self) private var notificationAuthorization
    @Environment(AppSettingsStore.self) private var settings
    @Environment(RuleEnforcer.self) private var enforcer
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query(sort: \BlockingRule.createdAt) private var rules: [BlockingRule]
    
    @State private var lifecycle = AppLifecycleController()
    @State private var retry = UUID()
    // State remains current inside the long-lived loop, unlike its captured
    // view's initial Environment value when the scene changes in the meantime.
    @State private var sceneIsActive = false

    var body: some View {
        Group {
            if lifecycle.preparationError {
                ContentUnavailableView {
                    Label(CopyKey.volitionSaveError.resource, systemImage: "exclamationmark.triangle")
                } actions: {
                    Button(CopyKey.volitionRetry.resource) { retry = UUID() }
                }
            } else if !lifecycle.prepared { ProgressView() }
            else if lifecycle.needsSetup {
                VolitionAppsView { lifecycle.needsSetup = false; conversation.selectedSection = .chat }
            } else { layout }
        }
            .safeAreaInset(edge: .top) {
                if lifecycle.health != .healthy {
                    HStack {
                        Image(systemName: "exclamationmark.shield")
                        Text((lifecycle.health == .degraded ? CopyKey.enforcementRecovered : .enforcementUncertain).resource)
                            .font(.footnote)
                        Button(CopyKey.volitionRetry.resource) { Task { await enforcer.acknowledgeRecovery(); refreshEnforcement() } }
                    }.padding().background(.regularMaterial)
                    .accessibilityIdentifier("enforcementHealthBanner")
                }
            }
            .task(id: retry) {
                await lifecycle.start(context: modelContext, settings: settings, enforcer: enforcer,
                    conversation: conversation, consumeRequests: sceneIsActive)
                guard lifecycle.prepared else { return }
                await focus.refresh()
                if ConversationShieldRoute.current == .notification {
                    await notificationAuthorization.refresh()
                    if notificationAuthorization.status == .notDetermined { await notificationAuthorization.request() }
                }
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
                if phase == .active {
                    Diag.log(.lifecycle, "refresh trigger: scenePhase active")
                    Task { await focus.refresh(); refreshEnforcement() }
                }
            }
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
        guard lifecycle.prepared else { return }
        // Enforcement I/O runs off the main thread inside the enforcer; this
        // fire-and-forget Task hands it the current rules and returns immediately.
        Task {
            await lifecycle.reconcile(load: { try modelContext.fetch(FetchDescriptor<BlockingRule>()) },
                enforcer: enforcer, conversation: conversation, consumeRequests: sceneIsActive)
        }
    }

    /// Keeps shields in sync while the app is open, so windows that begin or end
    /// while the user is looking at the screen take effect promptly.
    private func enforcementLoop() async {
        while !Task.isCancelled {
            await lifecycle.reconcile(load: { try modelContext.fetch(FetchDescriptor<BlockingRule>()) },
                enforcer: enforcer, conversation: conversation, consumeRequests: sceneIsActive)
            try? await Task.sleep(for: .seconds(30))
        }
    }
}
