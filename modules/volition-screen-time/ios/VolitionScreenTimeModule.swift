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
    private var enforcement: ConversationEnforcement {
        ConversationEnforcement(store: ConversationGrantStore(), shields: ManagedSettingsShieldController())
    }
    private func failure(_ message: String) -> NSError {
        NSError(domain: "VolitionScreenTime", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
    private func token(_ encoded: String) throws -> ApplicationToken {
        guard let data = Data(base64Encoded: encoded) else { throw failure("Invalid app selection") }
        return try JSONDecoder().decode(ApplicationToken.self, from: data)
    }
    private func grantRecord(_ grant: ConversationGrantStore.Grant, snapshots: [RuleSnapshotDTO]) -> [String: Any] {
        ["grantId": grant.plan.grantID.uuidString.lowercased(),
         "appId": ConversationGrantStore.applicable(to: grant.token, in: snapshots).first?.id.uuidString.lowercased() ?? "",
         "tokenBase64": (try? JSONEncoder().encode(grant.token).base64EncodedString()) ?? "",
         "minutes": grant.plan.minutes,
         "expiresAt": ISO8601DateFormatter().string(from: grant.plan.expiresAt)]
    }
    public func definition() -> ModuleDefinition {
        Name("VolitionScreenTime")
        AsyncFunction("requestAuthorization") { () -> String in
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            return await MainActor.run { AuthorizationCenter.shared.authorizationStatus == .approved ? "approved" : "denied" }
        }
        Function("getAuthorizationStatus") { () -> String in
            switch AuthorizationCenter.shared.authorizationStatus {
            case .approved: return "approved"
            case .denied: return "denied"
            case .notDetermined: return "notDetermined"
            @unknown default: return "unknown"
            }
        }
        AsyncFunction("presentAppPicker") { (promise: Promise) in
            Task { @MainActor in FamilyActivityPickerPresenter.shared.present(promise: promise) }
        }
        AsyncFunction("reconcileShields") { (apps: [SavedAppRecord]) -> String in
            let snapshots = try apps.map { app -> RuleSnapshotDTO in
                guard let id = UUID(uuidString: app.id), !app.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      app.name.count <= 600, !app.goal.isEmpty, app.goal.count <= 2000 else { throw self.failure("Invalid saved app") }
                var selection = FamilyActivitySelection()
                selection.applicationTokens = [try self.token(app.tokenBase64)]
                return RuleSnapshotDTO(id: id, name: app.name, kindRaw: RuleKind.conversation.rawValue,
                    isEnabled: app.isEnabled, hardMode: false, selectionModeRaw: SelectionMode.block.rawValue,
                    selectionData: AppSelectionCodec.encode(selection), dayNumbers: [], startMinutes: 0, endMinutes: 0,
                    dailyLimitMinutes: 0, maxOpens: 0, conversationGoal: app.goal)
            }
            guard Set(apps.map(\.tokenBase64)).count == apps.count else { throw self.failure("Duplicate app") }
            _ = try self.enforcement.sync(snapshots)
            return ConversationGrantStore.fingerprint(snapshots)
        }
        AsyncFunction("createGrant") { (encoded: String, minutes: Int, fingerprint: String, breakMinutes: Int?, overridingID: String?, relief: Bool, consentRevision: Int) -> [String: Any] in
            let active = await MainActor.run { UIApplication.shared.applicationState == .active }
            guard active else { throw self.failure("Open Volition to unlock") }
            let decodedToken = try self.token(encoded)
            let appIDs = try ConversationGrantStore().transaction { state in
                Set(ConversationGrantStore.applicable(to: decodedToken, in: state.snapshots).map(\.id))
            }
            let allowed = try await MainActor.run {
                let wait = try LegacyImport.shared.waitUntil(appIDs: appIDs)
                return AuthorizationCenter.shared.authorizationStatus == .approved && (wait.map { $0 <= Date() } ?? true)
            }
            guard allowed else { throw self.failure("An existing wait or permission prevents access") }
            let grant = try self.enforcement.approve(token: decodedToken, minutes: minutes, fingerprint: fingerprint,
                blockMinutes: breakMinutes, overridingDealID: overridingID.flatMap(UUID.init(uuidString:)), immediateRelief: relief, activationAllowed: {
                    AppGroup.defaults.bool(forKey: "expoAIConsent") && AppGroup.defaults.integer(forKey: "expoConsentRevision") == consentRevision
                })
            let snapshots = try ConversationGrantStore().transaction { $0.snapshots }
            return self.grantRecord(grant, snapshots: snapshots)
        }
        AsyncFunction("setAIConsent") { (allowed: Bool, revision: Int) in
            try ConversationGrantStore().transaction { _ in
                AppGroup.defaults.set(allowed, forKey: "expoAIConsent")
                AppGroup.defaults.set(revision, forKey: "expoConsentRevision")
            }
        }
        AsyncFunction("rollbackGrant") { (id: String) in
            guard let uuid = UUID(uuidString: id) else { throw self.failure("Invalid grant") }
            try self.enforcement.end(grantID: uuid, cancelDeal: true)
            await ConversationSessionPresentation.shared.end(uuid)
        }
        AsyncFunction("revokeGrant") { (id: String) in
            guard let uuid = UUID(uuidString: id) else { throw self.failure("Invalid grant") }
            try self.enforcement.end(grantID: uuid)
            await ConversationSessionPresentation.shared.end(uuid)
        }
        AsyncFunction("getActiveGrants") { () -> [[String: Any]] in
            self.enforcement.reconcileStored()
            return try ConversationGrantStore().transaction { state in
                state.activeGrants.map { self.grantRecord($0, snapshots: state.snapshots) }
            }
        }
        AsyncFunction("getCommitments") { () -> [[String: Any]] in
            try ConversationGrantStore().transaction { state in
                state.dealCommitments.map { deal in
                    ["grantId": deal.grantID.uuidString.lowercased(),
                     "appId": ConversationGrantStore.applicable(to: deal.token, in: state.snapshots).first?.id.uuidString.lowercased() ?? "",
                     "blockedUntil": ISO8601DateFormatter().string(from: deal.blockedUntil),
                     "pushbackCount": deal.pushbackCount ?? 0,
                     "overriddenAt": deal.overriddenAt.map { ISO8601DateFormatter().string(from: $0) as Any } ?? NSNull(),
                     "minimumReplacementBreakMinutes": ConversationEnforcement.minimumReplacementBreakMinutes(for: deal, at: .now)]
                }
            }
        }
        AsyncFunction("recordPushback") { (encoded: String) in
            try self.enforcement.recordDealPushback(token: self.token(encoded))
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
            let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: "volition.openai", kSecAttrAccount as String: "api-key"]
            let deletion = SecItemDelete(query as CFDictionary)
            guard deletion == errSecSuccess || deletion == errSecItemNotFound else { throw self.failure("Credential storage unavailable") }
            if !key.isEmpty {
                var item = query
                item[kSecValueData as String] = Data(key.utf8)
                item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
                guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { throw self.failure("Credential storage unavailable") }
            }
        }
        AsyncFunction("getAPIKey") { () -> String? in
            let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: "volition.openai", kSecAttrAccount as String: "api-key",
                kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
            var result: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            if status == errSecItemNotFound { return nil }
            guard status == errSecSuccess, let data = result as? Data else { throw self.failure("Credential storage unavailable") }
            return String(data: data, encoding: .utf8)
        }
        AsyncFunction("exportLegacyState") { () -> String in
            try await MainActor.run { try LegacyImport.shared.export() }
        }
        AsyncFunction("updateFocus") { (json: String) in
            let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
            let state = try decoder.decode(FocusProtectionState.self, from: Data(json.utf8))
            try self.enforcement.updateFocus(state, monitor: DeviceFocusMonitor())
        }
        AsyncFunction("getFocus") { () -> String in
            let state = try ConversationGrantStore().transaction { _ in try self.enforcement.focusStore.load() }
            let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
            return String(decoding: try encoder.encode(state), as: UTF8.self)
        }
        View(VolitionAppIconView.self) {
            Prop("tokenBase64") { (view: VolitionAppIconView, encoded: String) in view.updateToken(encoded) }
        }
    }
}
