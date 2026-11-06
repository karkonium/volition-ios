package expo.modules.volition

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.AtomicFile
import java.io.File
import java.io.FileNotFoundException
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/// Android Keystore protects the encryption key. Only ciphertext is stored on disk.
internal class CoachCredential(context: Context) {
    private val file = AtomicFile(File(context.noBackupFilesDir, "volition-coach"))
    private val keys = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }

    fun get(): String? {
        val bytes = try { file.readFully() } catch (_: FileNotFoundException) { return null }
        val key = keys.getKey(ALIAS, null) as? SecretKey ?: error("Credential storage unavailable")
        return Cipher.getInstance("AES/GCM/NoPadding").run {
            init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(128, bytes.copyOfRange(0, 12)))
            doFinal(bytes.copyOfRange(12, bytes.size)).toString(Charsets.UTF_8)
        }
    }

    fun set(value: String) {
        if (value.isEmpty()) {
            keys.deleteEntry(ALIAS)
            file.delete()
            return
        }
        val key = (keys.getKey(ALIAS, null) as? SecretKey) ?: KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore",
        ).run {
            init(KeyGenParameterSpec.Builder(ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .build())
            generateKey()
        }
        val bytes = Cipher.getInstance("AES/GCM/NoPadding").run {
            init(Cipher.ENCRYPT_MODE, key)
            check(iv.size == 12)
            iv + doFinal(value.toByteArray(Charsets.UTF_8))
        }
        val stream = file.startWrite()
        try {
            stream.write(bytes)
            stream.fd.sync()
            file.finishWrite(stream)
        } catch (failure: Exception) {
            file.failWrite(stream)
            throw failure
        }
    }

    private companion object {
        const val ALIAS = "volition.openai"
    }
}
