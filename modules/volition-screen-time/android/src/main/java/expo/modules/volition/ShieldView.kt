package expo.modules.volition

import android.content.Context
import android.content.res.ColorStateList
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.view.Gravity
import android.view.View
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import androidx.core.view.ViewCompat
import java.text.DateFormat
import java.util.Date
import java.util.Locale

internal data class ShieldCopy(val title: String, val subtitle: String, val primary: String, val secondary: String)

internal fun shieldCopy(context: Context, reasons: List<FocusOccurrence>, pending: Boolean): ShieldCopy {
    val focus = reasons.firstOrNull()
    val primary = context.getString(R.string.volition_close)
    if (focus == null) return ShieldCopy(
        context.getString(if (pending) R.string.volition_pending_title else R.string.volition_blocked_title),
        context.getString(R.string.volition_blocked_instructions),
        primary,
        context.getString(R.string.volition_request_access),
    )
    val locale: Locale = context.resources.configuration.locales[0]
    val end = DateFormat.getTimeInstance(DateFormat.SHORT, locale).format(Date(focus.endsAt))
    return ShieldCopy(
        focus.name ?: context.getString(R.string.volition_quick_focus),
        context.getString(if (reasons.size > 1) R.string.volition_focus_overlap else R.string.volition_focus_until, end),
        primary,
        context.getString(R.string.volition_review_focus),
    )
}

/// Mirrors the title, explanatory copy and two actions of the iOS shield.
/// Android owns the Home gesture and system bars around the overlay.
internal class ShieldView(context: Context, copy: ShieldCopy, close: () -> Unit, request: () -> Unit) :
    FrameLayout(context) {
    private val dark = resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK == Configuration.UI_MODE_NIGHT_YES
    private val accent = Color.rgb(0, 122, 255)
    private val ink = if (dark) Color.WHITE else Color.rgb(23, 23, 25)
    private val secondary = if (dark) Color.rgb(184, 184, 193) else Color.rgb(92, 92, 102)

    init {
        setBackgroundColor(if (dark) Color.rgb(28, 28, 30) else Color.rgb(245, 245, 248))
        isClickable = true
        val scroll = ScrollView(context).apply { isFillViewport = true }
        addView(scroll, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
        val content = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(dp(24), dp(24), dp(24), dp(24))
        }
        scroll.addView(content, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT))
        content.addView(View(context), LinearLayout.LayoutParams(1, 0, 1f))
        val text = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
        }
        content.addView(text, row())
        text.addView(TextView(context).apply {
            this.text = copy.title
            textSize = 26f
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(ink)
            gravity = Gravity.CENTER
            ViewCompat.setAccessibilityHeading(this, true)
        })
        text.addView(TextView(context).apply {
            this.text = copy.subtitle
            textSize = 16f
            setTextColor(secondary)
            gravity = Gravity.CENTER
            setPadding(0, dp(12), 0, 0)
        })
        content.addView(View(context), LinearLayout.LayoutParams(1, 0, 1f))
        content.addView(button(copy.primary, true, close), row())
        content.addView(button(copy.secondary, false, request), row())
    }

    private fun row() = LinearLayout.LayoutParams(
        (resources.displayMetrics.widthPixels - dp(48)).coerceIn(dp(1), dp(420)),
        LayoutParams.WRAP_CONTENT,
    )

    private fun button(label: String, primary: Boolean, action: () -> Unit) = Button(context).apply {
        text = label
        textSize = 17f
        isAllCaps = false
        minHeight = dp(52)
        minimumHeight = dp(52)
        setTextColor(if (primary) Color.WHITE else if (dark) Color.rgb(100, 176, 255) else Color.rgb(0, 91, 191))
        val shape = GradientDrawable().apply {
            cornerRadius = dp(12).toFloat()
            setColor(if (primary) accent else Color.TRANSPARENT)
        }
        background = RippleDrawable(ColorStateList.valueOf(0x22000000), shape, null)
        setOnClickListener { action() }
    }

    private fun dp(value: Int) = (value * resources.displayMetrics.density).toInt()
}
