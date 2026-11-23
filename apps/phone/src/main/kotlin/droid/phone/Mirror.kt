package droid.phone

import java.util.concurrent.ConcurrentHashMap

/** How to mirror (scrcpy's options). */
data class MirrorOptions(
    val audio: Boolean = true,
    val stayAwake: Boolean = true,
    val screenOff: Boolean = false,
    val onTop: Boolean = false,
    val maxSize: Int = 1920,
)

/** Mirroring windows: one scrcpy per phone. */
object Mirror {
    private val running = ConcurrentHashMap<String, Process>()

    val installed: Boolean
        get() = runCatching { ProcessBuilder("scrcpy", "--version").start().waitFor() == 0 }.getOrDefault(false)

    fun args(device: Device, o: MirrorOptions): List<String> = buildList {
        add("scrcpy")
        add("--serial=${device.serial}")
        add("--window-title=droid Phone — ${device.label}")
        add("--max-size=${o.maxSize}")
        if (!o.audio) add("--no-audio")
        if (o.stayAwake) add("--stay-awake")
        if (o.screenOff) add("--turn-screen-off")
        if (o.onTop) add("--always-on-top")
    }

    fun isRunning(serial: String) = running[serial]?.isAlive == true

    fun start(device: Device, options: MirrorOptions): String? {
        if (isRunning(device.serial)) return null
        return runCatching {
            running[device.serial] = ProcessBuilder(args(device, options)).inheritIO().start()
            null
        }.getOrElse { "scrcpy isn't installed: ./install.py packages -g phone" }
    }

    fun stop(serial: String) {
        running.remove(serial)?.destroy()
    }
}
