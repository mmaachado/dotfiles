package droid.phone

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

class AdbTest {
    @Test
    fun parsesUsbAndWirelessDevices() {
        val out = """
            List of devices attached
            R58M123ABC             device usb:1-2 product:a52q model:SM_A525F device:a52q transport_id:1
            192.168.1.20:41235     device product:shiba model:Pixel_8 device:shiba transport_id:3
            emulator-5554          unauthorized transport_id:4
        """.trimIndent()
        val devices = Adb.parseDevices(out)
        assertEquals(3, devices.size)
        assertEquals("SM A525F", devices[0].model)
        assertFalse(devices[0].wireless)
        assertTrue(devices[1].wireless)
        assertEquals("Pixel 8", devices[1].label)
        assertFalse(devices[2].ready)
        assertEquals("emulator-5554", devices[2].label)
    }

    @Test
    fun ignoresDaemonNoise() {
        val out = "* daemon not running; starting now at tcp:5037\n* daemon started successfully\nList of devices attached\n"
        assertEquals(emptyList(), Adb.parseDevices(out.lines().dropWhile { it.startsWith("*") }.joinToString("\n")))
    }

    @Test
    fun parsesMdnsServices() {
        val out = "List of discovered mdns services\nadb-R58M-AbC\t_adb-tls-connect._tcp\t192.168.1.20:41235\nstudio-k3x9\t_adb-tls-pairing._tcp\t192.168.1.20:37099\n"
        val services = Adb.parseMdns(out)
        assertEquals(2, services.size)
        assertTrue(services[0].connect)
        assertTrue(services[1].pairing)
        assertEquals("192.168.1.20:37099", services[1].address)
    }

    @Test
    fun parsesBattery() {
        assertEquals(87, Adb.parseBattery("Current Battery Service state:\n  AC powered: false\n  level: 87\n  scale: 100\n"))
        assertNull(Adb.parseBattery("nothing"))
    }

    @Test
    fun pairingPayloadHasAndroidsFormat() {
        val p = Pairing()
        assertTrue(Regex("""^WIFI:T:ADB;S:droid-[a-z0-9]{6};P:[a-z0-9]{10};;$""").matches(p.payload))
        val img = Pairing.qrImage(p.payload, 200)
        assertEquals(200, img.width)
    }

    @Test
    fun scrcpyArguments() {
        val d = Device("R58", "device", "Pixel 8", false)
        val args = Mirror.args(d, MirrorOptions(audio = false, screenOff = true))
        assertTrue("--serial=R58" in args)
        assertTrue("--no-audio" in args)
        assertTrue("--turn-screen-off" in args)
        assertTrue(args.any { it.startsWith("--window-title=droid Phone") })
    }
}
