package expo.modules.volition

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat

/// Countdowns and reminders are grant-specific and never control access.
internal class GrantNotifications(private val context: Context) {
    private val manager = context.getSystemService(NotificationManager::class.java)
    private val reminders = listOf(60, 30, 10)
    private val published = mutableMapOf<String, Long>()
    private val sent = mutableSetOf<String>()

    fun boundaries(grant: Grant, now: Long): List<Long> =
        listOf(grant.deadline) + reminders.map { grant.deadline - it * 1000 }.filter { it > now }

    fun sync(grants: List<Grant>, now: Long, copy: Context) {
        if (Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) return
        if (!manager.areNotificationsEnabled()) return
        manager.createNotificationChannels(listOf(
            NotificationChannel(TIMERS, copy.getString(R.string.volition_access_timers), NotificationManager.IMPORTANCE_LOW),
            NotificationChannel(REMINDERS, copy.getString(R.string.volition_access_reminders), NotificationManager.IMPORTANCE_DEFAULT),
        ))
        val live = grants.associateBy { it.id }
        manager.activeNotifications.filter { it.tag?.startsWith(TAG) == true }.forEach {
            if (it.tag.removePrefix(TAG).substringBefore(':') !in live) manager.cancel(it.tag, it.id)
        }
        published.keys.retainAll(live.keys)
        sent.removeAll { it.substringBefore(':') !in live }
        val open = context.packageManager.getLaunchIntentForPackage(context.packageName)?.let {
            PendingIntent.getActivity(context, 0, it, PendingIntent.FLAG_IMMUTABLE)
        }
        for (grant in grants) {
            val remaining = grant.deadline - now
            val group = TAG + grant.id
            val title = copy.getString(R.string.volition_unlocked, grant.app.name)
            fun notification(channel: String) = Notification.Builder(context, channel)
                .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
                .setContentTitle(title)
                .setContentIntent(open)
                .setVisibility(Notification.VISIBILITY_PRIVATE)
                .setTimeoutAfter(remaining)
            if (published[grant.id] != grant.deadline) {
                manager.notify(group, 0, notification(TIMERS).setWhen(grant.deadline).setUsesChronometer(true)
                    .setChronometerCountDown(true).setOngoing(true).setOnlyAlertOnce(true).build())
                published[grant.id] = grant.deadline
            }
            for (seconds in reminders) {
                val key = "${grant.id}:$seconds"
                if (remaining in (seconds * 1000L - 1500)..(seconds * 1000L) && sent.add(key)) {
                    val reminderGroup = "$group:reminders"
                    manager.notify(reminderGroup, 0, notification(REMINDERS).setGroup(reminderGroup)
                        .setGroupSummary(true).setGroupAlertBehavior(Notification.GROUP_ALERT_CHILDREN).build())
                    manager.notify("$TAG$key", 0, notification(REMINDERS).setGroup(reminderGroup)
                        .setGroupAlertBehavior(Notification.GROUP_ALERT_CHILDREN)
                        .setContentText(copy.getString(R.string.volition_seconds_remaining, seconds.toString())).build())
                }
            }
        }
    }

    fun clear() {
        manager.activeNotifications.filter { it.tag?.startsWith(TAG) == true }.forEach { manager.cancel(it.tag, it.id) }
        published.clear()
        sent.clear()
    }

    private companion object {
        const val TIMERS = "volition-timers"
        const val REMINDERS = "volition-reminders"
        const val TAG = "volition-grant:"
    }
}
