package expo.modules.volition

import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService

/// The tile uses the same saved scope and command as the Focus tab.
class QuickFocusTile : TileService() {
    override fun onStartListening() = refreshTile()

    private fun refreshTile() {
        val store = AccessStore.get(this)
        qsTile?.apply {
            label = store.localized(this@QuickFocusTile).getString(R.string.volition_quick_focus)
            state = if (AccessStore.disclosureAccepted(this@QuickFocusTile) &&
                VolitionBlockService.connected != null &&
                store.state.focus.session?.isActive(System.currentTimeMillis()) == true
            ) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
            updateTile()
        }
    }

    override fun onClick() {
        if (isLocked) unlockAndRun { toggle() } else toggle()
    }

    private fun toggle() {
        val now = System.currentTimeMillis()
        val store = AccessStore.get(this)
        val state = store.state.reconciled(now)
        val session = state.focus.session?.takeIf { it.isActive(now) }
        val command = FocusCommand(
            if (session == null) "startSession" else "endSession",
            null, null, session?.id, null, null, null,
        )
        val updated = runCatching {
            check(AccessStore.disclosureAccepted(this) && VolitionBlockService.connected != null)
            val focus = state.focus.apply(command, state.enabledIds, now)
            store.publish(state.copy(focus = focus).reconciled(now), now)
        }
        if (updated.isFailure) {
            val launch = packageManager.getLaunchIntentForPackage(packageName) ?: return
            if (Build.VERSION.SDK_INT >= 34) {
                startActivityAndCollapse(PendingIntent.getActivity(this, 0, launch, PendingIntent.FLAG_IMMUTABLE))
            } else {
                @Suppress("DEPRECATION")
                startActivityAndCollapse(launch)
            }
        } else {
            refreshTile()
        }
    }

    internal companion object {
        fun update(context: Context) = requestListeningState(context, ComponentName(context, QuickFocusTile::class.java))
    }
}
