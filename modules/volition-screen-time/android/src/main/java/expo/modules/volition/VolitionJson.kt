package expo.modules.volition

import com.google.gson.GsonBuilder

internal object VolitionJson {
    private val gson = GsonBuilder().serializeNulls().create()
    fun encode(value: Any): String = gson.toJson(value)
    fun <T> decode(json: String, type: Class<T>): T = requireNotNull(gson.fromJson(json, type))
}
