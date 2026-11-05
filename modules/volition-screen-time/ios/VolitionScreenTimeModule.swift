import ExpoModulesCore
import FamilyControls
import ManagedSettings
import DeviceActivity
import SwiftUI
import Security

struct SavedAppRecord: Record {
    @Field var id: String = ""
    @Field var name: String = ""
    @Field var goal: String = ""
    @Field var tokenBase64: String = ""
    @Field var isEnabled: Bool = true
}

/// The existing coordinated store remains authoritative. JavaScript receives a
/// grant only after timer registration, durable publication and shield readback.
public final class VolitionScreenTimeModule: Module {
    private static var enforcement: ConversationEnforcement {
        ConversationEnforcement(store: ConversationGrantStore(), shields: ManagedSettingsShieldController())
    }
    private static func failure(_ message: String) -> NSError {
        NSError(domain: "VolitionScreenTime", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
    private static func token(_ encoded: String) throws -> ApplicationToken {
        guard let data = Data(base64Encoded: encoded) else { throw failure("Invalid app selection") }
        return try JSONDecoder().decode(ApplicationToken.self, from: data)
    }
    private static func grantRecord(_ grant: ConversationGrantStore.Grant, snapshots: [RuleSnapshotDTO]) -> [String:
        Any]
    {
        [
            "grantId": grant.plan.grantID.uuidString.lowercased(),
            "appId": ConversationGrantStore.applicable(to: grant.token, in: snapshots).first?.id.uuidString.lowercased()
                ?? "",
            "tokenBase64": (try? JSONEncoder().encode(grant.token).base64EncodedString()) ?? "",
            "minutes": grant.plan.minutes,
            "expiresAt": ISO8601DateFormatter().string(from: grant.effectiveExpiry),
        ]
    }
    private static func authorizationStatus() -> String {
        switch AuthorizationCenter.shared.authorizationStatus {
        case .approved, .approvedWithDataAccess: return "approved"
        case .denied: return "denied"
        case .notDetermined: return "notDetermined"
        @unknown default: return "unknown"
        }
    }
    private static func focusSnapshot() throws -> String {
        let snapshot = try ConversationGrantStore().transaction { state in
            FocusSnapshot(state.focus ?? FocusProtectionState(), apps: state.focusAppIDs, now: .now)
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return String(decoding: try encoder.encode(snapshot), as: UTF8.self)
    }

    public func definition() -> ModuleDefinition {
        Name("VolitionScreenTime")
        AsyncFunction("requestAuthorization") { () -> String in
            // Dismissing Apple’s prompt is an ordinary, retryable outcome.
            do {
                try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            } catch FamilyControlsError.authorizationCanceled {
                return await MainActor.run { Self.authorizationStatus() }
            }
            return await MainActor.run { Self.authorizationStatus() }
        }
        Function("getAuthorizationStatus") { () -> String in
            Self.authorizationStatus()
        }
        AsyncFunction("presentAppPicker") { (promise: Promise) in
            Task { @MainActor in FamilyActivityPickerPresenter.shared.present(promise: promise) }
        }
        AsyncFunction("reconcileShields") { (apps: [SavedAppRecord]) -> String in
            let snapshots = try apps.map { app -> RuleSnapshotDTO in
                guard let id = UUID(uuidString: app.id),
                    !app.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    app.name.count <= 600, !app.goal.isEmpty, app.goal.count <= 2000
                else { throw Self.failure("Invalid saved app") }
                var selection = FamilyActivitySelection()
                selection.applicationTokens = [try Self.token(app.tokenBase64)]
                return RuleSnapshotDTO(
                    id: id, name: app.name, kindRaw: RuleKind.conversation.rawValue,
                    isEnabled: app.isEnabled, hardMode: false, selectionModeRaw: SelectionMode.block.rawValue,
                    selectionData: AppSelectionCodec.encode(selection), dayNumbers: [], startMinutes: 0, endMinutes: 0,
                    dailyLimitMinutes: 0, maxOpens: 0, conversationGoal: app.goal)
            }
            guard Set(apps.map(\.tokenBase64)).count == apps.count else { throw Self.failure("Duplicate app") }
            _ = try Self.enforcement.sync(snapshots)
            try ConversationGrantStore().transaction { _ in
                AppGroup.defaults.set(false, forKey: AppGroup.uninstallProtectionKey)
                ManagedSettingsShieldController().setAppRemovalDenied(false)
                RuleSnapshotUserDefaultsStore().save(snapshots)
            }
            RuleScheduler(monitor: DeviceActivityCenterMonitor()).sync(snapshots: snapshots)
            return ConversationGrantStore.fingerprint(snapshots)
        }
        AsyncFunction("createGrant") {
            (
                encoded: String, minutes: Int, fingerprint: String, breakMinutes: Int?, overridingID: String?,
                relief: Bool, consentRevision: Int
            ) -> [String: Any] in
            let active = await MainActor.run { UIApplication.shared.applicationState == .active }
            guard active else { throw Self.failure("Open Volition to unlock") }
            let decodedToken = try Self.token(encoded)
            let appIDs = try ConversationGrantStore().transaction { state in
                Set(ConversationGrantStore.applicable(to: decodedToken, in: state.snapshots).map(\.id))
            }
            let allowed = try await MainActor.run {
                let wait = try LegacyImport.shared.waitUntil(appIDs: appIDs)
                return Self.authorizationStatus() == "approved" && (wait.map { $0 <= Date() } ?? true)
            }
            guard allowed else { throw Self.failure("An existing wait or permission prevents access") }
            let grant: ConversationGrantStore.Grant
            do {
                grant = try Self.enforcement.approve(
                    token: decodedToken, minutes: minutes, fingerprint: fingerprint,
                    blockMinutes: breakMinutes, overridingDealID: overridingID.flatMap(UUID.init(uuidString:)),
                    immediateRelief: relief,
                    activationAllowed: {
                        AppGroup.defaults.bool(forKey: "expoAIConsent")
                            && AppGroup.defaults.integer(forKey: "expoConsentRevision") == consentRevision
                    })
            } catch let error as ConversationAccessError where error == .focusProtected || error == .focusBoundary {
                throw FocusBridgeError(code: error == .focusProtected ? "FOCUS_ACTIVE" : "FOCUS_BOUNDARY")
            }
            let snapshots = try ConversationGrantStore().transaction { $0.snapshots }
            return Self.grantRecord(grant, snapshots: snapshots)
        }
        AsyncFunction("setLanguage") { (language: String) in
            guard ["en", "es", "zh"].contains(language) else { return }
            AppGroup.defaults.set(language, forKey: "volitionLanguage")
        }
        AsyncFunction("setAIConsent") { (allowed: Bool, revision: Int) in
            try ConversationGrantStore().transaction { _ in
                AppGroup.defaults.set(allowed, forKey: "expoAIConsent")
                AppGroup.defaults.set(revision, forKey: "expoConsentRevision")
            }
        }
        AsyncFunction("rollbackGrant") { (id: String) in
            guard let uuid = UUID(uuidString: id) else { throw Self.failure("Invalid grant") }
            try Self.enforcement.end(grantID: uuid, cancelDeal: true)
            await ConversationSessionPresentation.shared.end(uuid)
        }
        AsyncFunction("revokeGrant") { (id: String) in
            guard let uuid = UUID(uuidString: id) else { throw Self.failure("Invalid grant") }
            try Self.enforcement.end(grantID: uuid)
            await ConversationSessionPresentation.shared.end(uuid)
        }
        AsyncFunction("getActiveGrants") { () -> [[String: Any]] in
            Self.enforcement.reconcileStored()
            return try ConversationGrantStore().transaction { state in
                state.activeGrants.map { Self.grantRecord($0, snapshots: state.snapshots) }
            }
        }
        AsyncFunction("getCommitments") { () -> [[String: Any]] in
            try ConversationGrantStore().transaction { state in
                state.dealCommitments.map { deal in
                    [
                        "grantId": deal.grantID.uuidString.lowercased(),
                        "appId": ConversationGrantStore.applicable(to: deal.token, in: state.snapshots).first?.id
                            .uuidString.lowercased() ?? "",
                        "blockedUntil": ISO8601DateFormatter().string(from: deal.blockedUntil),
                        "pushbackCount": deal.pushbackCount ?? 0,
                        "overriddenAt": deal.overriddenAt.map { ISO8601DateFormatter().string(from: $0) as Any }
                            ?? NSNull(),
                        "minimumReplacementBreakMinutes": ConversationEnforcement.minimumReplacementBreakMinutes(
                            for: deal, at: .now),
                    ]
                }
            }
        }
        AsyncFunction("recordPushback") { (encoded: String) in
            try Self.enforcement.recordDealPushback(token: Self.token(encoded))
        }
        AsyncFunction("consumeShieldRequest") { () -> String? in
            let active = await MainActor.run { UIApplication.shared.applicationState == .active }
            guard active, let request = ConversationRequestStore().pending() else { return nil }
            ConversationRequestStore().acknowledge(request)
            return request.appID.uuidString.lowercased()
        }
        AsyncFunction("syncPresentation") { () in
            let store = ConversationGrantStore()
            let unlocks = try store.transaction { state in
                state.activeGrants.map { grant in
                    let app = ConversationGrantStore.applicable(to: grant.token, in: state.snapshots).first
                    return ConversationPresentedUnlock(plan: grant.plan, appID: app?.id, appName: app?.name ?? "App")
                }
            }
            await ConversationSessionPresentation.shared.sync(unlocks, store: store)
        }
        AsyncFunction("setAPIKey") { (key: String) in
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: "volition.openai", kSecAttrAccount as String: "api-key",
            ]
            let deletion = SecItemDelete(query as CFDictionary)
            guard deletion == errSecSuccess || deletion == errSecItemNotFound else {
                throw Self.failure("Credential storage unavailable")
            }
            if !key.isEmpty {
                var item = query
                item[kSecValueData as String] = Data(key.utf8)
                item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
                guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else {
                    throw Self.failure("Credential storage unavailable")
                }
            }
        }
        AsyncFunction("getAPIKey") { () -> String? in
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: "volition.openai", kSecAttrAccount as String: "api-key",
                kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne,
            ]
            var result: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            if status == errSecItemNotFound { return nil }
            guard status == errSecSuccess, let data = result as? Data else {
                throw Self.failure("Credential storage unavailable")
            }
            return String(data: data, encoding: .utf8)
        }
        AsyncFunction("exportLegacyState") { () -> String in
            try await MainActor.run { try LegacyImport.shared.export() }
        }
        AsyncFunction("applyFocusCommand") { (json: String) -> String in
            let active = await MainActor.run { UIApplication.shared.applicationState == .active }
            guard active, Self.authorizationStatus() == "approved" else {
                throw FocusBridgeError(code: "FOCUS_PERMISSION")
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let command = try decoder.decode(FocusCommand.self, from: Data(json.utf8))
            do { try Self.enforcement.mutateFocus(command) } catch let error as ConversationAccessError {
                switch error {
                case .focusNeedsApps: throw FocusBridgeError(code: "FOCUS_APPS")
                case .focusInvalid: throw FocusBridgeError(code: "FOCUS_INVALID")
                case .staleRequest: throw FocusBridgeError(code: "FOCUS_STALE")
                default: throw FocusBridgeError(code: "FOCUS_REGISTRATION")
                }
            } catch { throw FocusBridgeError(code: "FOCUS_REGISTRATION") }
            return try Self.focusSnapshot()
        }
        AsyncFunction("getFocus") { () -> String in try Self.focusSnapshot() }
        AsyncFunction("repairFocusMonitoring") { () in
            do { try Self.enforcement.repairFocusMonitoring() } catch {
                throw FocusBridgeError(code: "FOCUS_REGISTRATION")
            }
        }
        View(FocusTimePickerView.self) {
            Events("onTimeChange")
            Prop("minutes") { (view: FocusTimePickerView, minutes: Int) in view.setMinutes(minutes) }
            Prop("label") { (view: FocusTimePickerView, label: String) in view.setLabel(label) }
        }
        View(VolitionAppIconView.self) {
            Prop("tokenBase64") { (view: VolitionAppIconView, encoded: String) in view.updateToken(encoded) }
        }
    }
}

private struct FocusBridgeError: CodedError {
    let code: String
    var description: String { code }
}
