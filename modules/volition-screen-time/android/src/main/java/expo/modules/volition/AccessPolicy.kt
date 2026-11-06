package expo.modules.volition

import androidx.annotation.Keep
import java.security.MessageDigest
import java.time.Instant
import java.util.UUID
import kotlin.math.ceil

internal const val MINUTE_MS = 60_000L
internal fun isoDate(millis: Long): String = Instant.ofEpochMilli(millis).toString()

@Keep
internal data class SavedApp(
    val id: String,
    val name: String,
    val goal: String,
    val tokenBase64: String,
    val isEnabled: Boolean,
)

@Keep
internal data class Grant(
    val id: String,
    val app: SavedApp,
    val minutes: Int,
    val expiresAt: Long,
    val focusCutoff: Long? = null,
) {
    val deadline get() = minOf(expiresAt, focusCutoff ?: expiresAt)

    fun bridgeRecord() = mapOf(
        "grantId" to id, "appId" to app.id, "tokenBase64" to app.tokenBase64,
        "minutes" to minutes, "expiresAt" to isoDate(deadline),
    )
}

@Keep
internal data class Deal(
    val grantId: String,
    val token: String,
    val blockedUntil: Long,
    val pushbackCount: Int = 0,
    val overriddenAt: Long? = null,
    val overrideGrantId: String? = null,
) {
    fun isBlocking(token: String, now: Long) =
        this.token == token && overriddenAt == null && blockedUntil > now

    fun minimumReplacement(now: Long) =
        (ceil((blockedUntil - now).coerceAtLeast(0) / MINUTE_MS.toDouble()).toInt() + 15).coerceIn(30, 1440)
}

internal class AccessFailure(val code: String, message: String = code) : IllegalStateException(message)

@Keep
internal data class AccessState(
    val apps: List<SavedApp> = emptyList(),
    val grants: List<Grant> = emptyList(),
    val deals: List<Deal> = emptyList(),
    val focus: FocusState = FocusState(),
    val consent: Boolean = false,
    val consentRevision: Int = 0,
) {
    val fingerprint: String
        get() = MessageDigest.getInstance("SHA-256").digest(
            VolitionJson.encode(apps.sortedBy { it.id }).toByteArray(Charsets.UTF_8),
        ).joinToString("") { "%02x".format(it) }

    val enabledIds get() = apps.filter { it.isEnabled }.mapTo(mutableSetOf()) { it.id }

    fun activeGrants(now: Long) = grants.filter { it.deadline > now && it.app in apps && it.app.isEnabled }

    /// A deal's break begins when its grant ends. During the grant it never blocks that grant.
    fun blocks(app: SavedApp, now: Long): Boolean =
        app.isEnabled && activeGrants(now).none { it.app == app }

    /// Refresh cutoffs before publishing a configuration change. Once a cutoff passes,
    /// a later edit or exception cannot revive the grant.
    fun reconciled(now: Long): AccessState {
        val occurrences = focus.occurrences(enabledIds, now)
        return copy(grants = activeGrants(now).mapNotNull { grant ->
            if (occurrences.active.any { it.protects(grant.app.id) }) return@mapNotNull null
            val cutoff = occurrences.upcoming.firstOrNull { it.protects(grant.app.id) }?.startsAt
            grant.copy(focusCutoff = cutoff?.takeIf { it < grant.expiresAt })
        })
    }

    fun approve(
        token: String, minutes: Int, fingerprint: String, breakMinutes: Int?,
        overridingId: String?, relief: Boolean, revision: Int, now: Long,
    ): Pair<AccessState, Grant> {
        require(minutes in 1..60 && (breakMinutes == null || breakMinutes in 1..1440))
        require(!relief || breakMinutes == null)
        check(consent && consentRevision == revision && this.fingerprint == fingerprint) {
            "Access settings changed. Request access again."
        }
        val app = apps.firstOrNull { it.isEnabled && it.tokenBase64 == token }
            ?: error("Choose a saved app")
        val live = activeGrants(now)
        check(live.none { it.app == app }) { "This app is already unlocked" }
        val grant = Grant(UUID.randomUUID().toString(), app, minutes, now + minutes * MINUTE_MS)
        val occurrences = focus.occurrences(setOf(app.id), now)
        if (occurrences.active.any { it.protects(app.id) }) throw AccessFailure("FOCUS_ACTIVE")
        if (occurrences.upcoming.any { it.startsAt < grant.expiresAt }) throw AccessFailure("FOCUS_BOUNDARY")
        val previous = deals.firstOrNull { it.isBlocking(token, now) }
        if (previous != null) {
            check(overridingId == previous.grantId && (relief ||
                (previous.pushbackCount >= 2 && breakMinutes != null && breakMinutes >= previous.minimumReplacement(now)))
            ) { "An accepted break prevents access" }
        } else {
            check(overridingId == null) { "The previous break has changed" }
        }
        var ledger = deals.map { deal ->
            if (deal == previous) deal.copy(overriddenAt = now, overrideGrantId = grant.id) else deal
        }
        if (breakMinutes != null) ledger = ledger + Deal(grant.id, token, grant.expiresAt + breakMinutes * MINUTE_MS)
        return copy(grants = live + grant, deals = ledger) to grant
    }

    fun end(id: String, rollback: Boolean) = copy(
        grants = grants.filterNot { it.id == id },
        deals = if (rollback) deals.filterNot { it.grantId == id }.map { deal ->
            if (deal.overrideGrantId == id) deal.copy(overriddenAt = null, overrideGrantId = null) else deal
        } else deals,
    )

    fun pushBack(token: String, now: Long): AccessState {
        if (activeGrants(now).any { it.app.tokenBase64 == token }) return this
        val current = deals.firstOrNull { it.isBlocking(token, now) } ?: return this
        return copy(deals = deals.map { deal ->
            if (deal == current) deal.copy(pushbackCount = (deal.pushbackCount + 1).coerceAtMost(1000)) else deal
        })
    }
}
