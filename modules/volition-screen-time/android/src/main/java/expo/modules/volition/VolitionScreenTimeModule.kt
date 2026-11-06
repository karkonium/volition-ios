package expo.modules.volition

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.provider.Settings
import com.facebook.react.bridge.ReactContext
import com.facebook.react.common.LifecycleState
import expo.modules.kotlin.Promise
import expo.modules.kotlin.exception.CodedException
import expo.modules.kotlin.functions.Queues
import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition
import expo.modules.kotlin.records.Field
import expo.modules.kotlin.records.Record

class SavedAppRecord : Record {
    @Field val id: String = ""
    @Field val name: String = ""
    @Field val goal: String = ""
    @Field val tokenBase64: String = ""
    @Field val isEnabled: Boolean = true
}

/// Serializes all enforcement operations with the service on Android's main looper.
class VolitionScreenTimeModule : Module() {
    private val context: Context get() = requireNotNull(appContext.reactContext)
    private val store get() = AccessStore.get(context)
    private var settingsResult: Promise? = null
    private val foreground get() = (appContext.reactContext as? ReactContext)?.lifecycleState == LifecycleState.RESUMED

    override fun definition() = ModuleDefinition {
        Name("VolitionScreenTime")
        Events("onShieldRequest")

        OnActivityEntersForeground {
            VolitionBlockService.connected?.volitionOpened()
        }
        OnNewIntent { intent ->
            if (intent.getBooleanExtra(VolitionBlockService.REQUEST_EXTRA, false)) sendEvent("onShieldRequest")
        }
        OnActivityResult { _, result ->
            if (result.requestCode == ACCESSIBILITY_REQUEST) {
                settingsResult?.resolve(authorizationStatus())
                settingsResult = null
            }
        }
        OnActivityDestroys {
            settingsResult?.resolve(authorizationStatus())
            settingsResult = null
        }

        Function("getAuthorizationStatus") { authorizationStatus() }
        AsyncFunction("requestAuthorization") { promise: Promise ->
            AccessStore.acceptDisclosure(context)
            if (authorizationStatus() == "approved") {
                promise.resolve("approved")
            } else {
                check(settingsResult == null)
                val activity = requireNotNull(appContext.currentActivity)
                settingsResult = promise
                try {
                    @Suppress("DEPRECATION")
                    activity.startActivityForResult(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS), ACCESSIBILITY_REQUEST)
                } catch (failure: Exception) {
                    settingsResult = null
                    throw failure
                }
            }
        }.runOnQueue(Queues.MAIN)
        AsyncFunction("presentAppPicker") { promise: Promise ->
            showAppPicker(requireNotNull(appContext.currentActivity), store.localized(context), promise)
        }.runOnQueue(Queues.MAIN)
        AsyncFunction("exportLegacyState") { """{"apps":[],"aiConsent":true,"history":{}}""" }

        AsyncFunction("reconcileShields") { apps: List<SavedAppRecord> ->
            val excluded = excludedPackages(context)
            val seen = mutableSetOf<String>()
            val ids = mutableSetOf<String>()
            val saved = apps.map {
                val packageName = packageFromToken(it.tokenBase64)
                require(packageName != null && packageName !in excluded && seen.add(packageName))
                require(it.id.isNotBlank() && ids.add(it.id))
                require(it.name.isNotBlank() && it.name.length <= 600 && it.goal.isNotEmpty() && it.goal.length <= 2000)
                SavedApp(it.id, it.name, it.goal, it.tokenBase64, it.isEnabled)
            }
            val now = System.currentTimeMillis()
            val next = store.state.reconciled(now).copy(apps = saved).reconciled(now)
            store.publish(next, now)
            next.fingerprint
        }.runOnQueue(Queues.MAIN)
        AsyncFunction("createGrant") {
                token: String, minutes: Int, fingerprint: String, breakMinutes: Int?,
                overridingId: String?, relief: Boolean, revision: Int ->
            val service = VolitionBlockService.connected
            check(foreground && authorizationStatus() == "approved" && service != null) {
                "Open Volition and enable app blocking to unlock"
            }
            coded {
                val now = System.currentTimeMillis()
                val previous = store.state.reconciled(now)
                val (next, grant) = previous.approve(token, minutes, fingerprint, breakMinutes, overridingId, relief, revision, now)
                try {
                    store.publish(next, now)
                    check(service === VolitionBlockService.connected &&
                        !store.state.blocks(grant.app, System.currentTimeMillis())
                    ) { "Could not confirm app access" }
                } catch (failure: Exception) {
                    store.publish(store.state.end(grant.id, rollback = true), System.currentTimeMillis())
                    throw failure
                }
                grant.bridgeRecord()
            }
        }.runOnQueue(Queues.MAIN)
        AsyncFunction("rollbackGrant") { id: String ->
            store.publish(store.state.end(id, rollback = true), System.currentTimeMillis())
        }.runOnQueue(Queues.MAIN)
        AsyncFunction("revokeGrant") { id: String ->
            store.publish(store.state.end(id, rollback = false), System.currentTimeMillis())
        }.runOnQueue(Queues.MAIN)
        AsyncFunction("getActiveGrants") {
            val now = System.currentTimeMillis()
            store.state.reconciled(now).activeGrants(now).map { it.bridgeRecord() }
        }.runOnQueue(Queues.MAIN)
        AsyncFunction("getCommitments") {
            val state = store.state
            val now = System.currentTimeMillis()
            state.deals.map { deal ->
                mapOf(
                    "grantId" to deal.grantId,
                    "appId" to (state.apps.firstOrNull { it.tokenBase64 == deal.token && it.isEnabled }?.id ?: ""),
                    "blockedUntil" to isoDate(deal.blockedUntil),
                    "pushbackCount" to deal.pushbackCount,
                    "overriddenAt" to deal.overriddenAt?.let(::isoDate),
                    "minimumReplacementBreakMinutes" to deal.minimumReplacement(now),
                )
            }
        }.runOnQueue(Queues.MAIN)
        AsyncFunction("recordPushback") { token: String ->
            store.commit(store.state.pushBack(token, System.currentTimeMillis()))
        }.runOnQueue(Queues.MAIN)
        AsyncFunction("setAIConsent") { allowed: Boolean, revision: Int ->
            store.commit(store.state.copy(consent = allowed, consentRevision = revision))
        }.runOnQueue(Queues.MAIN)
        AsyncFunction("setLanguage") { language: String ->
            if (language in setOf("en", "es", "zh")) store.setLanguage(language)
            Unit
        }.runOnQueue(Queues.MAIN)

        AsyncFunction("consumeShieldRequest") {
            if (foreground) store.consume(System.currentTimeMillis()) else null
        }.runOnQueue(Queues.MAIN)
        AsyncFunction("syncPresentation") {
            VolitionBlockService.connected?.refresh()
            Unit
        }.runOnQueue(Queues.MAIN)
        AsyncFunction("setAPIKey") { key: String -> CoachCredential(context).set(key) }.runOnQueue(Queues.MAIN)
        AsyncFunction("getAPIKey") { CoachCredential(context).get() }.runOnQueue(Queues.MAIN)

        AsyncFunction("getFocus") {
            val state = store.state
            state.focus.snapshot(state.enabledIds, System.currentTimeMillis())
        }.runOnQueue(Queues.MAIN)
        AsyncFunction("repairFocusMonitoring") {
            val service = VolitionBlockService.connected ?: throw CodedException("FOCUS_REGISTRATION", "FOCUS_REGISTRATION", null)
            service.refresh()
        }.runOnQueue(Queues.MAIN)
        AsyncFunction("applyFocusCommand") { json: String ->
            coded {
                if (!foreground || authorizationStatus() != "approved" || VolitionBlockService.connected == null)
                    throw AccessFailure("FOCUS_PERMISSION")
                val now = System.currentTimeMillis()
                val state = store.state.reconciled(now)
                val command = VolitionJson.decode(json, FocusCommand::class.java)
                val next = state.copy(focus = state.focus.apply(command, state.enabledIds, now)).reconciled(now)
                store.publish(next, now)
                next.focus.snapshot(next.enabledIds, now)
            }
        }.runOnQueue(Queues.MAIN)
        View(VolitionAppIconView::class) {
            Prop("tokenBase64") { view: VolitionAppIconView, token: String -> view.update(token) }
        }
    }

    private fun authorizationStatus(): String {
        if (!AccessStore.disclosureAccepted(context)) return "notDetermined"
        val service = ComponentName(context, VolitionBlockService::class.java)
        val enabled = Settings.Secure.getString(context.contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES)
        return if (enabled?.split(':')?.any { ComponentName.unflattenFromString(it) == service } == true)
            "approved" else "notDetermined"
    }

    private fun <T> coded(action: () -> T): T = try {
        action()
    } catch (error: AccessFailure) {
        throw CodedException(error.code, error.message, error)
    }

    private companion object {
        const val ACCESSIBILITY_REQUEST = 0x7011
    }
}
