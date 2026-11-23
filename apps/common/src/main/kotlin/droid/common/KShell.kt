package droid.common

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonObject
import java.io.File
import java.util.concurrent.TimeUnit

/** Talking to the running shell: its IPC targets and its settings file. */
object KShell {
    val settingsFile: File =
        File(System.getProperty("user.home"), ".config/quickshell/kshell/config/settings.json")

    /** `qs -c kshell ipc call <target> <function> [args]`; its output, or null if it failed. */
    fun ipc(target: String, function: String, vararg args: String): String? = runCatching {
        val p = ProcessBuilder("qs", "-c", "kshell", "ipc", "call", target, function, *args)
            .redirectErrorStream(true).start()
        val out = p.inputStream.bufferedReader().readText().trim()
        if (p.waitFor(5, TimeUnit.SECONDS) && p.exitValue() == 0) out else null
    }.getOrNull()

    /** KShell's settings (config/settings.json), empty if there are none yet. */
    fun settings(): JsonObject = runCatching {
        Json.parseToJsonElement(settingsFile.readText()).jsonObject
    }.getOrElse { JsonObject(emptyMap()) }
}
