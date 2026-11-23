package droid.phone

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.draganddrop.dragAndDropTarget
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.PhoneAndroid
import androidx.compose.material.icons.filled.Usb
import androidx.compose.material.icons.filled.Wifi
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRow
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.draganddrop.DragAndDropEvent
import androidx.compose.ui.draganddrop.DragAndDropTarget
import androidx.compose.ui.draganddrop.awtTransferable
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Window
import androidx.compose.ui.window.application
import androidx.compose.ui.window.rememberWindowState
import droid.common.DroidTheme
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.awt.FileDialog
import java.awt.Frame
import java.awt.datatransfer.DataFlavor
import java.io.File

fun main() = application {
    Window(
        onCloseRequest = ::exitApplication,
        state = rememberWindowState(size = DpSize(860.dp, 560.dp)),
        title = "droid Phone",
    ) {
        DroidTheme { PhoneScreen() }
    }
}

@Composable
fun PhoneScreen() {
    var devices by remember { mutableStateOf(emptyList<Device>()) }
    var selected by remember { mutableStateOf<String?>(null) }
    var status by remember { mutableStateOf("") }
    var pairing by remember { mutableStateOf(false) }
    var adbMissing by remember { mutableStateOf(false) }

    // Phones come and go (cables, Wi-Fi), so keep looking.
    LaunchedEffect(Unit) {
        while (true) {
            withContext(Dispatchers.IO) {
                adbMissing = !Adb.available
                devices = if (adbMissing) emptyList() else Adb.devices()
            }
            if (selected == null || devices.none { it.serial == selected }) selected = devices.firstOrNull { it.ready }?.serial
            delay(3000)
        }
    }

    Surface(color = MaterialTheme.colorScheme.surface, modifier = Modifier.fillMaxSize()) {
        Row(Modifier.fillMaxSize()) {
            // ── Devices ──────────────────────────────────────────────
            Column(Modifier.width(260.dp).fillMaxHeight().background(MaterialTheme.colorScheme.surfaceContainer).padding(12.dp)) {
                Text("Phones", style = MaterialTheme.typography.titleLarge, modifier = Modifier.padding(8.dp))
                LazyColumn(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    items(devices, key = { it.serial }) { d ->
                        DeviceRow(d, d.serial == selected) { selected = d.serial }
                    }
                }
                FilledTonalButton(onClick = { pairing = true }, modifier = Modifier.fillMaxWidth()) {
                    Icon(Icons.Filled.Add, null)
                    Spacer(Modifier.width(8.dp))
                    Text("Pair over Wi-Fi")
                }
            }

            // ── The selected phone ───────────────────────────────────
            Box(Modifier.weight(1f).fillMaxHeight().padding(24.dp)) {
                val device = devices.firstOrNull { it.serial == selected }
                when {
                    adbMissing -> Empty("adb isn't installed", "Install the phone tools: ./install.py packages -g phone")
                    device == null -> Empty(
                        "No phone connected",
                        "Plug a phone in by USB with USB debugging on, or pair one over Wi-Fi (Developer options → Wireless debugging).",
                    )
                    else -> DevicePane(device) { status = it }
                }
                if (status.isNotEmpty()) Text(
                    status,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.align(Alignment.BottomStart),
                )
            }
        }
    }

    if (pairing) PairDialog(onDone = { msg -> pairing = false; if (msg.isNotEmpty()) status = msg })
}

@Composable
fun DeviceRow(d: Device, selected: Boolean, onClick: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp))
            .background(if (selected) MaterialTheme.colorScheme.secondaryContainer else MaterialTheme.colorScheme.surfaceContainer)
            .clickable(onClick = onClick).padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(if (d.wireless) Icons.Filled.Wifi else Icons.Filled.Usb, null)
        Spacer(Modifier.width(12.dp))
        Column {
            Text(d.label, fontWeight = FontWeight.Medium)
            Text(
                when (d.state) {
                    "device" -> if (d.wireless) "Wi-Fi" else "USB"
                    "unauthorized" -> "Allow USB debugging on the phone"
                    else -> d.state
                },
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
fun Empty(title: String, body: String) {
    Column(Modifier.fillMaxSize(), verticalArrangement = Arrangement.Center, horizontalAlignment = Alignment.CenterHorizontally) {
        Icon(Icons.Filled.PhoneAndroid, null, Modifier.size(64.dp), tint = MaterialTheme.colorScheme.outline)
        Spacer(Modifier.height(16.dp))
        Text(title, style = MaterialTheme.typography.titleMedium)
        Spacer(Modifier.height(6.dp))
        Text(body, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@OptIn(ExperimentalFoundationApi::class, ExperimentalComposeUiApi::class)
@Composable
fun DevicePane(device: Device, onStatus: (String) -> Unit) {
    val scope = rememberCoroutineScope()
    var options by remember { mutableStateOf(MirrorOptions()) }
    var battery by remember(device.serial) { mutableStateOf<Int?>(null) }
    var tick by remember { mutableIntStateOf(0) }
    var dropping by remember { mutableStateOf(false) }

    LaunchedEffect(device.serial) {
        while (true) {
            if (device.ready) battery = withContext(Dispatchers.IO) { Adb.battery(device.serial) }
            tick++
            delay(10_000)
        }
    }

    fun send(files: List<File>) {
        scope.launch {
            onStatus("Sending ${files.size} file(s) to ${device.label}…")
            val r = withContext(Dispatchers.IO) { Adb.push(device.serial, files) }
            onStatus(if (r.ok) "Sent to the phone's Download folder" else "Couldn't send: ${r.output.lines().lastOrNull() ?: ""}")
        }
    }

    // Drop files anywhere on the pane to send them.
    val dropTarget = remember(device.serial) {
        object : DragAndDropTarget {
            override fun onEntered(event: DragAndDropEvent) { dropping = true }
            override fun onExited(event: DragAndDropEvent) { dropping = false }
            override fun onEnded(event: DragAndDropEvent) { dropping = false }
            override fun onDrop(event: DragAndDropEvent): Boolean {
                dropping = false
                val t = event.awtTransferable
                if (!t.isDataFlavorSupported(DataFlavor.javaFileListFlavor)) return false
                @Suppress("UNCHECKED_CAST")
                send(t.getTransferData(DataFlavor.javaFileListFlavor) as List<File>)
                return true
            }
        }
    }

    Column(
        Modifier.fillMaxSize()
            .dragAndDropTarget(shouldStartDragAndDrop = { device.ready }, target = dropTarget)
            .border(if (dropping) 2.dp else 0.dp, MaterialTheme.colorScheme.primary, RoundedCornerShape(24.dp))
            .padding(8.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Text(device.label, style = MaterialTheme.typography.headlineMedium)
        Text(
            listOfNotNull(
                if (device.wireless) "Wi-Fi" else "USB",
                battery?.let { "Battery $it%" },
                device.serial,
            ).joinToString("  ·  "),
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )

        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            val mirroring = tick >= 0 && Mirror.isRunning(device.serial)
            Button(enabled = device.ready, onClick = {
                if (mirroring) Mirror.stop(device.serial) else Mirror.start(device, options)?.let(onStatus)
                tick++
            }) { Text(if (mirroring) "Stop mirroring" else "Mirror") }
            OutlinedButton(enabled = device.ready, onClick = {
                val dialog = FileDialog(null as Frame?, "Send to ${device.label}", FileDialog.LOAD).apply {
                    isMultipleMode = true
                    isVisible = true
                }
                if (dialog.files.isNotEmpty()) send(dialog.files.toList())
            }) { Text("Send files…") }
            if (device.wireless) TextButton(onClick = {
                scope.launch(Dispatchers.IO) { Adb.disconnect(device.serial) }
            }) { Text("Disconnect") }
        }

        Option("Phone audio on this computer", options.audio) { options = options.copy(audio = it) }
        Option("Keep the phone awake", options.stayAwake) { options = options.copy(stayAwake = it) }
        Option("Turn the phone's screen off while mirroring", options.screenOff) { options = options.copy(screenOff = it) }
        Option("Mirror window always on top", options.onTop) { options = options.copy(onTop = it) }

        Text(
            "Drop files here to send them to the phone's Download folder.",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
fun Option(label: String, value: Boolean, onChange: (Boolean) -> Unit) {
    Row(Modifier.fillMaxWidth().padding(end = 16.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(label, Modifier.weight(1f))
        Switch(value, onChange)
    }
}

/** Pair over Wi-Fi: scan a QR code, or type the pairing code. */
@Composable
fun PairDialog(onDone: (String) -> Unit) {
    var tab by remember { mutableIntStateOf(0) }
    val pairing = remember { Pairing() }
    val qr = remember { pairing.qr() }
    var message by remember { mutableStateOf("Waiting for the phone…") }
    var address by remember { mutableStateOf("") }
    var code by remember { mutableStateOf("") }
    val scope = rememberCoroutineScope()

    // QR: the phone advertises our service name once it has scanned the code.
    LaunchedEffect(tab) {
        if (tab != 0) return@LaunchedEffect
        while (true) {
            val service = withContext(Dispatchers.IO) { Adb.mdnsServices() }.firstOrNull { it.pairing && it.name == pairing.name }
            if (service != null) {
                message = "Pairing…"
                val r = withContext(Dispatchers.IO) { Adb.pair(service.address, pairing.password) }
                if (r.ok) {
                    connectAfterPairing(service.address)
                    onDone("Paired. The phone shows up in the list in a moment.")
                    return@LaunchedEffect
                }
                message = "Pairing failed: ${r.output.lines().lastOrNull() ?: ""}"
            }
            delay(1500)
        }
    }

    AlertDialog(
        onDismissRequest = { onDone("") },
        title = { Text("Pair a phone over Wi-Fi") },
        text = {
            Column(Modifier.width(420.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                TabRow(selectedTabIndex = tab) {
                    Tab(tab == 0, { tab = 0 }, text = { Text("QR code") })
                    Tab(tab == 1, { tab = 1 }, text = { Text("Pairing code") })
                }
                if (tab == 0) {
                    Text("On the phone: Settings → Developer options → Wireless debugging → Pair device with QR code. Both need to be on the same network.")
                    Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                        Image(qr, "Pairing QR code", Modifier.size(220.dp).clip(RoundedCornerShape(12.dp)))
                    }
                    Text(message, color = MaterialTheme.colorScheme.onSurfaceVariant)
                } else {
                    Text("On the phone: Wireless debugging → Pair device with pairing code. Type the IP address and port, and the code, it shows.")
                    OutlinedTextField(address, { address = it }, label = { Text("IP address and port") }, singleLine = true)
                    OutlinedTextField(code, { code = it }, label = { Text("Pairing code") }, singleLine = true)
                    if (message.startsWith("Pairing failed")) Text(message, color = MaterialTheme.colorScheme.error)
                }
            }
        },
        confirmButton = {
            if (tab == 1) TextButton(onClick = {
                scope.launch {
                    message = "Pairing…"
                    val r = withContext(Dispatchers.IO) { Adb.pair(address.trim(), code.trim()) }
                    if (r.ok) {
                        connectAfterPairing(address.trim())
                        onDone("Paired. The phone shows up in the list in a moment.")
                    } else message = "Pairing failed: ${r.output.lines().lastOrNull() ?: ""}"
                }
            }, enabled = address.isNotBlank() && code.isNotBlank()) { Text("Pair") }
        },
        dismissButton = { TextButton(onClick = { onDone("") }) { Text("Cancel") } },
    )
}

/**
 * After pairing, connect to the phone's debugging service. It's
 * advertised over mDNS on another port; if it doesn't show up, adb usually
 * connects on its own.
 */
suspend fun connectAfterPairing(pairAddress: String) = withContext(Dispatchers.IO) {
    val host = pairAddress.substringBefore(":")
    repeat(10) {
        Adb.mdnsServices().firstOrNull { it.connect && it.address.startsWith("$host:") }?.let {
            Adb.connect(it.address)
            return@withContext
        }
        delay(1000)
    }
}
