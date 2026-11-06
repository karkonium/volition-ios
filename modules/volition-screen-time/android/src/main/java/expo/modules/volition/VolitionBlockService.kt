package expo.modules.volition

import android.accessibilityservice.AccessibilityService
import android.app.KeyguardManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.res.Configuration
import android.graphics.PixelFormat
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import android.view.View
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import androidx.core.content.ContextCompat

/// Reads only window package changes. The service can cover a selected app and
/// route a user tap to Volition, and has no access to the app's UI tree or text.
class VolitionBlockService : AccessibilityService() {
    private val handler = Handler(Looper.getMainLooper())
    private val store by lazy { AccessStore.get(this) }
    private val windows by lazy { getSystemService(WindowManager::class.java) }
    private val notices by lazy { GrantNotifications(this) }
    private var foregroundPackage: String? = null
    private var overlay: View? = null
    private var shown: ShieldCopy? = null
    private var registered = false
    private var quickFocusActive = false
    private val tick = Runnable { refresh() }
    private val systemChanges = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action == Intent.ACTION_SCREEN_OFF) hide()
            else refresh()
        }
    }

    override fun onServiceConnected() {
        connected = this
        if (!registered) {
            val actions = IntentFilter().apply {
                addAction(Intent.ACTION_SCREEN_OFF)
                addAction(Intent.ACTION_SCREEN_ON)
                addAction(Intent.ACTION_USER_PRESENT)
                addAction(Intent.ACTION_TIME_CHANGED)
                addAction(Intent.ACTION_TIMEZONE_CHANGED)
            }
            ContextCompat.registerReceiver(this, systemChanges, actions, ContextCompat.RECEIVER_NOT_EXPORTED)
            registered = true
        }
        refresh()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        if (!AccessStore.disclosureAccepted(this)) return
        val next = event.packageName?.toString() ?: return
        val host = packageManager.getLaunchIntentForPackage(packageName)?.component?.className
        // Our overlay itself can emit a window event. Only the host activity counts
        // as a switch to Volition. IME window changes are also not app switches.
        if (next == packageName && event.className?.toString() != host) return
        val keyboard = Settings.Secure.getString(contentResolver, Settings.Secure.DEFAULT_INPUT_METHOD)
        if (keyboard?.substringBefore('/') == next) return
        if (next == foregroundPackage) return
        foregroundPackage = next
        refresh()
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        hide()
        refresh()
    }

    override fun onInterrupt() = Unit

    override fun onUnbind(intent: Intent?): Boolean {
        disconnect()
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        disconnect()
        if (registered) unregisterReceiver(systemChanges)
        super.onDestroy()
    }

    private fun disconnect() {
        if (connected === this) {
            connected = null
            runCatching { notices.clear() }
            runCatching { QuickFocusTile.update(this) }
        }
        handler.removeCallbacks(tick)
        hide()
    }

    internal fun volitionOpened() {
        foregroundPackage = packageName
        hide()
    }

    /// Register the next deadline on the service before exposing a new grant.
    /// The same callback always reevaluates current state, including replacement grants.
    internal fun schedule(state: AccessState, now: Long): Boolean {
        handler.removeCallbacks(tick)
        val active = state.activeGrants(now)
        val focusBoundary = state.focus.occurrences(state.enabledIds, now).nextRefreshAt
        val next = (active.flatMap { notices.boundaries(it, now) } + listOfNotNull(focusBoundary)).minOrNull()
        return next == null || handler.postDelayed(tick, (next - now).coerceAtLeast(1))
    }

    internal fun refresh() {
        if (connected !== this || !AccessStore.disclosureAccepted(this)) return
        val now = System.currentTimeMillis()
        val state = try {
            store.state.reconciled(now).also {
                // A failed cleanup write cannot extend a grant past its deadline.
                runCatching { store.commit(it) }
            }
        } catch (_: Exception) {
            Log.e("VolitionBlock", "Could not read blocking state")
            return
        }
        schedule(state, now)
        val sessionActive = state.focus.session?.isActive(now) == true
        if (sessionActive != quickFocusActive) {
            quickFocusActive = sessionActive
            runCatching { QuickFocusTile.update(this) }
        }
        runCatching { notices.sync(state.activeGrants(now), now, store.localized(this)) }
        val app = state.apps.firstOrNull {
            it.isEnabled && packageFromToken(it.tokenBase64) == foregroundPackage
        }
        val visible = getSystemService(PowerManager::class.java).isInteractive &&
            !getSystemService(KeyguardManager::class.java).isKeyguardLocked
        if (!visible || app == null || !state.blocks(app, now)) {
            hide()
            return
        }
        val focus = state.focus.occurrences(state.enabledIds, now).active.filter { it.protects(app.id) }
        val copy = shieldCopy(store.localized(this), focus, store.pending(now) == app.id)
        if (shown == copy && overlay != null) return
        show(app, copy)
    }

    private fun show(app: SavedApp, copy: ShieldCopy) {
        hide()
        val view = ShieldView(this, copy, close = {
            performGlobalAction(GLOBAL_ACTION_HOME)
        }, request = { requestAccess(app) })
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.OPAQUE,
        )
        params.title = "Volition"
        try {
            windows.addView(view, params)
            overlay = view
            shown = copy
        } catch (_: WindowManager.BadTokenException) {
            Log.e("VolitionBlock", "Could not attach blocking window")
        }
    }

    private fun requestAccess(app: SavedApp) {
        try {
            val intent = packageManager.getLaunchIntentForPackage(packageName)
                ?: error("Volition activity unavailable")
            store.request(app.id, System.currentTimeMillis())
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            intent.putExtra(REQUEST_EXTRA, true)
            startActivity(intent)
        } catch (_: Exception) {
            Log.w("VolitionBlock", "Open Volition directly to continue the request")
        }
        refresh()
    }

    private fun hide() {
        overlay?.let { runCatching { windows.removeViewImmediate(it) } }
        overlay = null
        shown = null
    }

    internal companion object {
        const val REQUEST_EXTRA = "expo.modules.volition.SHIELD_REQUEST"
        var connected: VolitionBlockService? = null
            private set
    }
}
