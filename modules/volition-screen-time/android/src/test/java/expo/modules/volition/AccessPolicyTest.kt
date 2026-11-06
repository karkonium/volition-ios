package expo.modules.volition

import java.time.Instant
import java.time.ZoneId
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class AccessPolicyTest {
    private val start = 1_000_000L
    private val app = SavedApp("app", "Music", "Listen intentionally", "token", true)
    private val other = SavedApp("other", "Maps", "Directions", "other-token", true)
    private val state = AccessState(apps = listOf(app, other), consent = true, consentRevision = 2)

    @Test fun oneMinuteGrantReblocksAtTheDeadline() {
        val (next, grant) = state.approve(app.tokenBase64, 1, state.fingerprint, null, null, false, 2, start)
        assertEquals(start + 60_000, grant.expiresAt)
        assertFalse(next.blocks(app, grant.expiresAt - 1))
        assertTrue(next.blocks(app, grant.expiresAt))
        assertTrue(next.blocks(other, start))
    }

    @Test fun anotherAppEditAndAStaleEndPreserveTheDeadline() {
        val (next, grant) = state.approve(app.tokenBase64, 1, state.fingerprint, null, null, false, 2, start)
        val edited = next.copy(apps = listOf(app, other.copy(name = "Transit")))
        assertEquals(grant, edited.end("stale", false).activeGrants(start).single())
        assertTrue(edited.copy(apps = listOf(app.copy(goal = "New intention"))).blocks(app, start))
    }

    @Test fun endingAndRollingBackADealHaveDifferentEffects() {
        val (next, grant) = state.approve(app.tokenBase64, 1, state.fingerprint, 15, null, false, 2, start)
        assertEquals(grant.expiresAt + 15 * 60_000, next.end(grant.id, false).deals.single().blockedUntil)
        assertTrue(next.end(grant.id, true).deals.isEmpty())
    }

    @Test fun aFocusSessionCutsOffAccessAndAnExceptionDoesNotRestoreIt() {
        val (unlocked, _) = state.approve(app.tokenBase64, 1, state.fingerprint, null, null, false, 2, start)
        val session = FocusSession("focus", start + 10_000, FocusPreferences(15, true, emptySet()))
        val focused = unlocked.copy(focus = FocusState(session = session)).reconciled(session.startedAt)
        assertTrue(focused.blocks(app, session.startedAt))
        val exception = FocusCommand("exceptApp", null, null, null, null, session.id, app.id)
        val next = focused.copy(focus = focused.focus.apply(exception, focused.enabledIds, session.startedAt))
        assertTrue(next.blocks(app, session.startedAt))
        assertFalse(next.focus.occurrences(next.enabledIds, session.startedAt).active.single().protects(app.id))
        assertTrue(next.focus.occurrences(next.enabledIds, session.startedAt).active.single().protects(other.id))
    }

    @Test fun theSecondDayOfAnOvernightRoutineBelongsToTheStartingDay() {
        val utc = ZoneId.of("UTC")
        val mondayNight = FocusPeriod("routine", "Evening", setOf(2), 23 * 60, 2 * 60, true, true, emptySet())
        val focus = FocusState(periods = listOf(mondayNight))
        val tuesday = Instant.parse("2026-11-03T01:30:00Z").toEpochMilli()
        val occurrence = focus.occurrences(setOf(app.id), tuesday, utc).active.single()
        assertEquals("2026-11-03T02:00:00Z", isoDate(occurrence.endsAt))
        assertTrue(focus.occurrences(setOf(app.id), occurrence.endsAt, utc).active.isEmpty())
    }

    @Test fun changedConsentCannotPublishAGrant() {
        assertThrows(IllegalStateException::class.java) {
            state.approve(app.tokenBase64, 1, state.fingerprint, null, null, false, 1, start)
        }
    }
}
