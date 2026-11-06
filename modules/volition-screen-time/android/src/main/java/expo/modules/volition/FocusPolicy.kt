package expo.modules.volition

import androidx.annotation.Keep
import java.time.Instant
import java.time.ZoneId
import java.util.UUID

@Keep
internal data class FocusPeriod(
    val id: String, val name: String, val weekdays: Set<Int>, val startMinutes: Int,
    val endMinutes: Int, val isEnabled: Boolean, val allApps: Boolean, val appIDs: Set<String>,
    val version: String? = null,
) {
    val valid get() = name.isNotBlank() && name.length <= 100 &&
        weekdays.isNotEmpty() && weekdays.all { it in 1..7 } &&
        startMinutes in 0..1439 && endMinutes in 0..1439 &&
        (endMinutes - startMinutes + 1440) % 1440 >= 15
}

@Keep
internal data class FocusPreferences(val minutes: Int, val allApps: Boolean, val appIDs: Set<String>)

@Keep
internal data class FocusSession(val id: String, val startedAt: Long, val preferences: FocusPreferences) {
    val endsAt get() = startedAt + preferences.minutes * MINUTE_MS
    fun isActive(now: Long) = now in startedAt until endsAt
}

@Keep
internal data class FocusException(val occurrenceId: String, val appId: String, val endsAt: Long)

@Keep
internal data class FocusCommand(
    val kind: String, val expectedRevision: Int?, val period: FocusPeriod?, val sourceId: String?,
    val preferences: FocusPreferences?, val occurrenceID: String?, val appID: String?,
)

internal data class FocusOccurrence(
    val id: String, val sourceId: String, val kind: String, val name: String?,
    val appIDs: Set<String>, val exceptedAppIDs: Set<String>, val startsAt: Long, val endsAt: Long,
) {
    fun protects(appId: String) = appId in appIDs && appId !in exceptedAppIDs
    fun bridgeRecord() = mapOf(
        "id" to id, "sourceId" to sourceId, "kind" to kind, "name" to name,
        "appIDs" to appIDs, "exceptedAppIDs" to exceptedAppIDs,
        "startsAt" to isoDate(startsAt), "endsAt" to isoDate(endsAt),
    )
}

internal data class FocusOccurrences(val active: List<FocusOccurrence>, val upcoming: List<FocusOccurrence>) {
    val nextRefreshAt get() = listOfNotNull(active.firstOrNull()?.endsAt, upcoming.firstOrNull()?.startsAt).minOrNull()
}

@Keep
internal data class FocusState(
    val revision: Int = 0, val periods: List<FocusPeriod> = emptyList(),
    val session: FocusSession? = null, val preferences: FocusPreferences? = null,
    val exceptions: List<FocusException> = emptyList(),
) {
    /// Routines use local wall time and belong to the day they start. Quick Focus
    /// uses an absolute deadline, so changing time zones does not move its end.
    fun occurrences(appIds: Set<String>, now: Long, zone: ZoneId = ZoneId.systemDefault()): FocusOccurrences {
        val active = mutableListOf<FocusOccurrence>()
        val upcoming = mutableListOf<FocusOccurrence>()
        val today = Instant.ofEpochMilli(now).atZone(zone).toLocalDate()
        fun add(id: String, sourceId: String, kind: String, name: String?, apps: Set<String>, start: Long, end: Long) {
            if (apps.isEmpty() || end <= now || end <= start) return
            val skipped = exceptions.filter { it.occurrenceId == id && it.endsAt > now && it.appId in apps }
                .mapTo(mutableSetOf()) { it.appId }
            val item = FocusOccurrence(id, sourceId, kind, name, apps, skipped, start, end)
            (if (start <= now) active else upcoming).add(item)
        }
        session?.takeIf { it.isActive(now) }?.let {
            val scope = it.preferences
            add(it.id, it.id, "session", null, scope(scope.allApps, scope.appIDs, appIds), it.startedAt, it.endsAt)
        }
        for (period in periods.filter { it.isEnabled }) {
            val apps = scope(period.allApps, period.appIDs, appIds)
            if (apps.isEmpty()) continue
            for (offset in -1L..7L) {
                val day = today.plusDays(offset)
                if (day.dayOfWeek.value % 7 + 1 !in period.weekdays) continue
                val endDay = if (period.endMinutes < period.startMinutes) day.plusDays(1) else day
                val start = day.atStartOfDay().plusMinutes(period.startMinutes.toLong()).atZone(zone).toInstant().toEpochMilli()
                val end = endDay.atStartOfDay().plusMinutes(period.endMinutes.toLong()).atZone(zone).toInstant().toEpochMilli()
                val id = "${period.id}:${period.version}:${start / 1000}"
                add(id, period.id, "routine", period.name, apps, start, end)
                if (start > now && end > start) break
            }
        }
        return FocusOccurrences(
            active.sortedWith(compareBy({ it.endsAt }, { it.id })),
            upcoming.sortedWith(compareBy({ it.startsAt }, { it.id })),
        )
    }

    fun snapshot(apps: Set<String>, now: Long): String {
        val occurrences = occurrences(apps, now)
        val current = session?.takeIf { it.isActive(now) }
        return VolitionJson.encode(mapOf(
            "revision" to revision, "periods" to periods, "preferences" to preferences,
            "session" to current?.let {
                mapOf("id" to it.id, "start" to isoDate(it.startedAt), "minutes" to it.preferences.minutes,
                    "appIDs" to it.preferences.appIDs, "allApps" to it.preferences.allApps)
            },
            "observedAt" to isoDate(now),
            "active" to occurrences.active.map { it.bridgeRecord() },
            "upcoming" to occurrences.upcoming.map { it.bridgeRecord() },
            "nextRefreshAt" to occurrences.nextRefreshAt?.let(::isoDate),
        ))
    }

    fun apply(command: FocusCommand, apps: Set<String>, now: Long): FocusState {
        fun fail(code: String): Nothing = throw AccessFailure(code)
        if (command.expectedRevision != null && command.expectedRevision != revision) fail("FOCUS_STALE")
        val next = when (command.kind) {
            "saveRoutine" -> {
                val period = command.period?.takeIf { it.valid } ?: fail("FOCUS_INVALID")
                if (period.isEnabled && !period.allApps && period.appIDs.none { it in apps }) fail("FOCUS_APPS")
                val saved = period.copy(version = UUID.randomUUID().toString(), appIDs = if (period.allApps) emptySet() else period.appIDs)
                val index = periods.indexOfFirst { it.id == period.id }
                val updated = if (index == -1) periods + saved else periods.toMutableList().apply { this[index] = saved }
                if (updated.count { it.isEnabled } > 18) fail("FOCUS_REGISTRATION")
                copy(periods = updated)
            }
            "deleteRoutine" -> {
                val id = command.sourceId ?: fail("FOCUS_INVALID")
                copy(periods = periods.filterNot { it.id == id })
            }
            "savePreferences" -> {
                val value = command.preferences?.takeIf { it.minutes in 15..180 } ?: fail("FOCUS_INVALID")
                if (scope(value.allApps, value.appIDs, apps).isEmpty()) fail("FOCUS_APPS")
                copy(preferences = value.copy(appIDs = if (value.allApps) emptySet() else value.appIDs))
            }
            "startSession" -> {
                if (session?.isActive(now) == true) return this
                val value = preferences ?: fail("FOCUS_APPS")
                if (scope(value.allApps, value.appIDs, apps).isEmpty()) fail("FOCUS_APPS")
                copy(session = FocusSession(UUID.randomUUID().toString(), now, value))
            }
            "endSession" -> {
                if (command.sourceId != session?.id) fail("FOCUS_STALE")
                copy(session = null)
            }
            "exceptApp" -> {
                val app = command.appID ?: fail("FOCUS_STALE")
                val reason = occurrences(apps, now).active.firstOrNull {
                    it.id == command.occurrenceID && it.protects(app)
                } ?: fail("FOCUS_STALE")
                copy(exceptions = exceptions.filter { it.endsAt > now } + FocusException(reason.id, app, reason.endsAt))
            }
            else -> fail("FOCUS_INVALID")
        }
        return if (next == this) this else next.copy(revision = revision + 1)
    }

    private fun scope(all: Boolean, selected: Set<String>, apps: Set<String>) =
        if (all) apps else apps.intersect(selected)
}
