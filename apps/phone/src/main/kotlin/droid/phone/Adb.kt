package droid.phone

import java.io.File
import java.util.concurrent.TimeUnit

/** A phone adb can see. */
data class Device(
    val serial: String,
    val state: String,
    val model: String,
    val wireless: Boolean,
) {
    val ready get() = state == "device"
    val label get() = model.ifEmpty { serial }
}

/** A service a phone advertises over mDNS (`adb mdns services`). */
data class MdnsService(val name: String, val type: String, val address: String) {
    val pairing get() = type.startsWith("_adb-tls-pairing")
    val connect get() = type.startsWith("_adb-tls-connect")
}

/** adb, and the parsing of what it prints. */
object Adb {
    data class Result(val ok: Boolean, val output: String)

    fun run(vararg args: String, timeoutSec: Long = 15): Result = runCatching {
        val p = ProcessBuilder("adb", *args).redirectErrorStream(true).start()
        val out = p.inputStream.bufferedReader().readText()
        val done = p.waitFor(timeoutSec, TimeUnit.SECONDS)
        if (!done) p.destroyForcibly()
        Result(done && p.exitValue() == 0, out.trim())
    }.getOrElse { Result(false, it.message ?: "adb isn't installed") }

    val available: Boolean
        get() = run("version", timeoutSec = 5).ok

    fun devices(): List<Device> = parseDevices(run("devices", "-l").output)

    fun mdnsServices(): List<MdnsService> = parseMdns(run("mdns", "services").output)

    /** `adb pair host:port code`, for Wi-Fi debugging's pairing code or QR. */
    fun pair(address: String, code: String) = run("pair", address, code, timeoutSec = 30)

    fun connect(address: String) = run("connect", address, timeoutSec = 20)

    fun disconnect(serial: String) = run("disconnect", serial)

    /** Copy files to the phone's Downloads folder. */
    fun push(serial: String, files: List<File>): Result {
        val paths = files.filter { it.exists() }.map { it.absolutePath }
        if (paths.isEmpty()) return Result(false, "nothing to send")
        return run("-s", serial, "push", *paths.toTypedArray(), "/sdcard/Download/", timeoutSec = 600)
    }

    /** Battery level in percent, or null. */
    fun battery(serial: String): Int? =
        parseBattery(run("-s", serial, "shell", "dumpsys", "battery", timeoutSec = 5).output)

    // ── Parsing ──────────────────────────────────────────────────────

    /**
     * `adb devices -l`:
     *     List of devices attached
     *     R58M123ABC   device usb:1-2 product:a52q model:SM_A525F device:a52q transport_id:1
     *     192.168.1.20:41235 device product:... model:Pixel_8 device:shiba transport_id:3
     */
    fun parseDevices(out: String): List<Device> = out.lines()
        .drop(1)
        .map { it.trim() }
        .filter { it.isNotEmpty() && !it.startsWith("*") }
        .mapNotNull { line ->
            val parts = line.split(Regex("\\s+"))
            if (parts.size < 2) return@mapNotNull null
            val fields = parts.drop(2).mapNotNull { f -> f.split(":", limit = 2).takeIf { it.size == 2 }?.let { it[0] to it[1] } }.toMap()
            val serial = parts[0]
            Device(
                serial = serial,
                state = parts[1],
                model = fields["model"]?.replace('_', ' ') ?: "",
                wireless = ":" in serial || serial.contains("._adb-tls-connect"),
            )
        }

    /**
     * `adb mdns services`:
     *     List of discovered mdns services
     *     adb-R58M123-AbCdEf	_adb-tls-connect._tcp	192.168.1.20:41235
     *     studio-k3x9	_adb-tls-pairing._tcp	192.168.1.20:37099
     */
    fun parseMdns(out: String): List<MdnsService> = out.lines()
        .drop(1)
        .mapNotNull { line ->
            val parts = line.trim().split(Regex("\\s+"))
            if (parts.size >= 3 && parts[1].startsWith("_adb")) MdnsService(parts[0], parts[1].removeSuffix("."), parts[2]) else null
        }

    /** `dumpsys battery`'s "  level: 87". */
    fun parseBattery(out: String): Int? =
        Regex("""(?m)^\s*level:\s*(\d+)""").find(out)?.groupValues?.get(1)?.toIntOrNull()
}
