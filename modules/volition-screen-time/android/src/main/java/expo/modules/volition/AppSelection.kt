package expo.modules.volition

import android.app.Activity
import android.app.AlertDialog
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.provider.Settings
import android.util.Base64
import android.widget.ImageView
import expo.modules.kotlin.AppContext
import expo.modules.kotlin.Promise
import expo.modules.kotlin.views.ExpoView

private val packagePattern = Regex("[A-Za-z][A-Za-z0-9_]*(\\.[A-Za-z][A-Za-z0-9_]*)+")

internal fun packageFromToken(token: String): String? = runCatching {
    Base64.decode(token, Base64.NO_WRAP).toString(Charsets.UTF_8).takeIf { packagePattern.matches(it) }
}.getOrNull()

internal fun excludedPackages(context: Context): Set<String> {
    val manager = context.packageManager
    val home = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
    val settings = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
    return manager.queryIntentActivities(home, 0).mapTo(mutableSetOf(context.packageName, "com.android.systemui", "com.android.settings")) {
        it.activityInfo.packageName
    }.apply {
        manager.resolveActivity(settings, PackageManager.MATCH_DEFAULT_ONLY)?.activityInfo?.packageName?.let(::add)
    }
}

internal fun showAppPicker(activity: Activity, copy: Context, promise: Promise) {
    val manager = activity.packageManager
    val launcher = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
    val excluded = excludedPackages(activity)
    val choices = manager.queryIntentActivities(launcher, 0)
        .filterNot { it.activityInfo.packageName in excluded }
        .distinctBy { it.activityInfo.packageName }
        .map { it.activityInfo.packageName to it.loadLabel(manager).toString() }
        .sortedWith(compareBy(String.CASE_INSENSITIVE_ORDER) { it.second })
    AlertDialog.Builder(activity)
        .setTitle(copy.getString(R.string.volition_choose_app))
        .setItems(choices.map { it.second }.toTypedArray()) { _, index ->
            val token = Base64.encodeToString(choices[index].first.toByteArray(Charsets.UTF_8), Base64.NO_WRAP)
            promise.resolve(mapOf("tokenBase64" to token))
        }
        .setOnCancelListener { promise.reject("ERR_PICKER_CANCELLED", "App selection cancelled", null) }
        .show()
}

internal class VolitionAppIconView(context: Context, appContext: AppContext) : ExpoView(context, appContext) {
    private val image = ImageView(context).apply {
        scaleType = ImageView.ScaleType.FIT_CENTER
        importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_NO
    }

    init {
        addView(image, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
    }

    fun update(token: String) {
        val packageName = packageFromToken(token)
        image.setImageDrawable(packageName?.let { runCatching { context.packageManager.getApplicationIcon(it) }.getOrNull() })
    }
}
