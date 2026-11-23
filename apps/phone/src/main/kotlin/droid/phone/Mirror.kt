package droid.phone

import java.util.concurrent.ConcurrentHashMap

/** How to mirror (scrcpy's options). */
data class MirrorOptions(
    val audio: Boolean = true,
    val stayAwake: Boolean = true,
    val screenOff: Boolean = false,
    val onTop: Boolean = false,
    val maxSize: Int = 1920,
    /** When mirroring ends, turn off Developer options and USB debugging. */
    val lockdownOnStop: Boolean = true,
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

    /**
     * Start mirroring. [onEnded] runs when the mirror window closes, however
     * that happens (Stop mirroring, closing the window, unplugging).
     */
    fun start(device: Device, options: MirrorOptions, onEnded: (String) -> Unit = {}): String? {
        if (isRunning(device.serial)) return null
        return runCatching {
            val p = ProcessBuilder(args(device, options)).inheritIO().start()
            running[device.serial] = p
            p.onExit().thenRun {
                running.remove(device.serial, p)
                onEnded(if (options.lockdownOnStop) lockdown(device) else "")
            }
            null
        }.getOrElse { "scrcpy isn't installed: ./install.py packages -g phone" }
    }

    /** Turn off Developer options and USB debugging; a status line. */
    fun lockdown(device: Device): String {
        val r = Adb.lockdown(device.serial)
        // adb usually reports an error here: the connection drops as
        // debugging goes off, which is the point.
        return if (r.ok || "closed" in r.output || "error" in r.output || r.output.isEmpty())
            "Developer options and USB debugging are off on ${device.label}. Turn them back on on the phone to mirror again."
        else "Couldn't turn off debugging: ${r.output.lines().lastOrNull() ?: ""}"
    }

    fun stop(serial: String) {
        running.remove(serial)?.destroy()
    }
}
