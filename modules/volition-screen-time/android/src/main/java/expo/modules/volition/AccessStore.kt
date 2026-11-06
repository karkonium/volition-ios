package expo.modules.volition

import android.content.Context
import android.content.res.Configuration
import android.util.AtomicFile
import java.io.File
import java.io.FileNotFoundException
import java.util.Locale

/// The service and Expo module share a process and serialize writes on its main looper.
internal class AccessStore(context: Context) {
    private val file = AtomicFile(File(context.noBackupFilesDir, "volition-access.json"))
    private val routing = routingPreferences(context)
    var state: AccessState = try {
        VolitionJson.decode(file.readFully().toString(Charsets.UTF_8), AccessState::class.java)
    } catch (_: FileNotFoundException) {
        AccessState()
    }
        private set

    fun commit(next: AccessState) {
        if (next == state) return
        val bytes = VolitionJson.encode(next).toByteArray(Charsets.UTF_8)
        val stream = file.startWrite()
        try {
            stream.write(bytes)
            stream.fd.sync()
            file.finishWrite(stream)
        } catch (failure: Exception) {
            file.failWrite(stream)
            throw failure
        }
        state = next
    }

    /// Register the service deadline before exposing a change. If storage fails,
    /// the service reads the previous snapshot and restores its previous timer.
    fun publish(next: AccessState, now: Long) {
        val service = VolitionBlockService.connected
        try {
            check(service?.schedule(next, now) != false) { "Could not register the blocking deadline" }
            commit(next)
        } finally {
            service?.refresh()
        }
    }

    fun request(appId: String, now: Long) {
        check(routing.edit().putString("appId", appId).putLong("requestedAt", now).commit())
    }

    fun pending(now: Long): String? {
        val at = routing.getLong("requestedAt", 0)
        return routing.getString("appId", null)?.takeIf { now - at in 0..(5 * MINUTE_MS) }
    }

    fun consume(now: Long): String? {
        val app = pending(now) ?: return null
        check(routing.edit().remove("appId").remove("requestedAt").commit())
        return app
    }

    fun setLanguage(language: String) {
        routing.edit().putString("language", language).apply()
    }

    fun localized(context: Context): Context {
        val language = routing.getString("language", null) ?: return context
        val locale = Locale.forLanguageTag(if (language == "zh") "zh-CN" else language)
        return context.createConfigurationContext(Configuration(context.resources.configuration).apply { setLocale(locale) })
    }

    companion object {
        private var instance: AccessStore? = null

        private fun routingPreferences(context: Context) =
            context.getSharedPreferences("volition-shield-routing", Context.MODE_PRIVATE)

        // These preferences can also be read by the synchronous Expo status call.
        fun disclosureAccepted(context: Context) =
            routingPreferences(context).getBoolean("disclosureAccepted", false)

        fun acceptDisclosure(context: Context) {
            check(routingPreferences(context).edit().putBoolean("disclosureAccepted", true).commit())
        }

        // Every caller is on the main thread, including the first service callback.
        fun get(context: Context): AccessStore =
            instance ?: AccessStore(context.applicationContext).also { instance = it }
    }
}
