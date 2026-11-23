package droid.markup

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Redo
import androidx.compose.material.icons.automirrored.filled.Undo
import androidx.compose.material.icons.filled.BlurOn
import androidx.compose.material.icons.filled.BorderColor
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.Crop
import androidx.compose.material.icons.filled.CropSquare
import androidx.compose.material.icons.filled.Draw
import androidx.compose.material.icons.filled.NorthEast
import androidx.compose.material.icons.filled.RadioButtonUnchecked
import androidx.compose.material.icons.filled.Save
import androidx.compose.material.icons.filled.SaveAs
import androidx.compose.material.icons.filled.TextFields
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.FilledTonalIconButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.IconToggleButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.toComposeImageBitmap
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.isCtrlPressed
import androidx.compose.ui.input.key.isShiftPressed
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.type
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Window
import androidx.compose.ui.window.application
import androidx.compose.ui.window.rememberWindowState
import droid.common.DroidTheme
import java.awt.FileDialog
import java.awt.Frame
import java.awt.Image
import java.awt.Toolkit
import java.awt.datatransfer.DataFlavor
import java.awt.datatransfer.Transferable
import java.io.File
import javax.imageio.ImageIO
import kotlin.math.min
import kotlin.system.exitProcess

enum class Tool(val label: String, val icon: ImageVector) {
    Pen("Pen", Icons.Filled.Draw),
    Highlight("Highlight", Icons.Filled.BorderColor),
    Arrow("Arrow", Icons.Filled.NorthEast),
    Box("Rectangle", Icons.Filled.CropSquare),
    Oval("Ellipse", Icons.Filled.RadioButtonUnchecked),
    Text("Text", Icons.Filled.TextFields),
    Pixelate("Pixelate", Icons.Filled.BlurOn),
    Crop("Crop", Icons.Filled.Crop),
}

val palette = listOf(
    Color(0xFFFF453A), Color(0xFFFF9F0A), Color(0xFFFFD60A), Color(0xFF32D74B),
    Color(0xFF0A84FF), Color(0xFFBF5AF2), Color.White, Color.Black,
)

fun main(args: Array<String>) {
    val file = args.firstOrNull()?.let(::File)
    if (file == null || !file.isFile) {
        System.err.println("usage: droid-markup <image>")
        exitProcess(2)
    }
    val image = ImageIO.read(file) ?: run {
        System.err.println("droid-markup: can't read ${file.path}")
        exitProcess(1)
    }
    application {
        val state = rememberWindowState(size = androidx.compose.ui.unit.DpSize(1100.dp, 760.dp))
        val editor = remember { Editor(Document(image), file) }
        Window(
            onCloseRequest = ::exitApplication,
            state = state,
            title = "droid Markup — ${file.name}",
            onKeyEvent = { editor.onKey(it) },
        ) {
            DroidTheme { MarkupScreen(editor) }
        }
    }
}

/** The editor's state: the document, the tool and what's being drawn. */
class Editor(val doc: Document, var file: File) {
    var tool by mutableStateOf(Tool.Pen)
    var color by mutableStateOf(palette[0])
    var width by mutableStateOf(6f)
    /** Bumped on every change, so the preview re-renders. */
    var revision by mutableIntStateOf(0)
    var draft by mutableStateOf<Mark?>(null)
    var cropDraft by mutableStateOf<Rect?>(null)
    var textAt by mutableStateOf<Offset?>(null)
    var status by mutableStateOf("")

    fun changed() {
        revision++
    }

    fun undo() { doc.undo(); changed() }
    fun redo() { doc.redo(); changed() }

    fun save(target: File = file) {
        val out = Render.render(doc)
        val format = target.extension.lowercase().takeIf { it in listOf("png", "jpg", "jpeg") } ?: "png"
        val img = if (format == "png") out else java.awt.image.BufferedImage(out.width, out.height, java.awt.image.BufferedImage.TYPE_INT_RGB)
            .also { it.createGraphics().apply { drawImage(out, 0, 0, java.awt.Color.WHITE, null); dispose() } }
        ImageIO.write(img, format, target)
        file = target
        status = "Saved ${target.name}"
    }

    fun saveAs() {
        val current = file
        val dialog = FileDialog(null as Frame?, "Save As", FileDialog.SAVE).apply {
            directory = current.parent
            file = current.nameWithoutExtension + " (edited).png"
            isVisible = true
        }
        val name = dialog.file ?: return
        save(File(dialog.directory, name))
    }

    fun copy() {
        val img = Render.render(doc)
        Toolkit.getDefaultToolkit().systemClipboard.setContents(object : Transferable {
            override fun getTransferDataFlavors() = arrayOf(DataFlavor.imageFlavor)
            override fun isDataFlavorSupported(flavor: DataFlavor) = flavor == DataFlavor.imageFlavor
            override fun getTransferData(flavor: DataFlavor): Image = img
        }, null)
        status = "Copied to the clipboard"
    }

    fun onKey(e: androidx.compose.ui.input.key.KeyEvent): Boolean {
        if (e.type != KeyEventType.KeyDown || !e.isCtrlPressed) return false
        when (e.key) {
            Key.Z -> if (e.isShiftPressed) redo() else undo()
            Key.Y -> redo()
            Key.S -> if (e.isShiftPressed) saveAs() else save()
            Key.C -> copy()
            else -> return false
        }
        return true
    }
}

@Composable
fun MarkupScreen(editor: Editor) {
    Surface(color = MaterialTheme.colorScheme.surface, modifier = Modifier.fillMaxSize()) {
        Column(Modifier.fillMaxSize()) {
            Toolbar(editor)
            Box(Modifier.weight(1f).fillMaxWidth().padding(16.dp)) {
                Canvas(editor)
            }
            Text(
                editor.status.ifEmpty { "${editor.doc.image.width} × ${editor.doc.image.height}   ·   Ctrl+S save, Ctrl+Shift+S save as, Ctrl+C copy, Ctrl+Z undo" },
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(start = 20.dp, bottom = 10.dp),
            )
        }
    }
    val at = editor.textAt
    if (at != null) TextDialog(
        onDone = { text ->
            if (text.isNotBlank()) {
                editor.doc.add(Mark.Label(at, text, editor.color, editor.width * 6 + 12))
                editor.changed()
            }
            editor.textAt = null
        },
    )
}

@Composable
fun Toolbar(editor: Editor) {
    Surface(color = MaterialTheme.colorScheme.surfaceContainer) {
        Row(
            Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            for (tool in Tool.entries) {
                IconToggleButton(checked = editor.tool == tool, onCheckedChange = { editor.tool = tool }) {
                    Icon(tool.icon, contentDescription = tool.label,
                        tint = if (editor.tool == tool) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface)
                }
            }
            Spacer(Modifier.width(12.dp))
            for (c in palette) {
                Box(
                    Modifier.size(24.dp).clip(CircleShape).background(c)
                        .border(if (editor.color == c) 3.dp else 1.dp,
                            if (editor.color == c) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.outline, CircleShape)
                        .clickable { editor.color = c },
                )
                Spacer(Modifier.width(2.dp))
            }
            Spacer(Modifier.width(12.dp))
            for ((w, label) in listOf(3f to "S", 6f to "M", 12f to "L")) {
                TextButton(onClick = { editor.width = w }) {
                    Text(label, color = if (editor.width == w) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
            Spacer(Modifier.weight(1f))
            IconButton(onClick = editor::undo, enabled = editor.revision >= 0 && editor.doc.canUndo) {
                Icon(Icons.AutoMirrored.Filled.Undo, "Undo")
            }
            IconButton(onClick = editor::redo, enabled = editor.revision >= 0 && editor.doc.canRedo) {
                Icon(Icons.AutoMirrored.Filled.Redo, "Redo")
            }
            IconButton(onClick = editor::copy) { Icon(Icons.Filled.ContentCopy, "Copy") }
            IconButton(onClick = editor::saveAs) { Icon(Icons.Filled.SaveAs, "Save as") }
            FilledTonalIconButton(onClick = { editor.save() }) { Icon(Icons.Filled.Save, "Save") }
        }
    }
}

@Composable
fun Canvas(editor: Editor) {
    val doc = editor.doc
    // The committed marks, rendered once per change (crop shown as an overlay).
    val bitmap = remember(editor.revision) { Render.render(doc, cropped = false).toComposeImageBitmap() }
    val iw = doc.image.width.toFloat()
    val ih = doc.image.height.toFloat()

    Canvas(
        Modifier.fillMaxSize()
            .pointerInput(editor.tool, editor.color, editor.width) {
                fun fit(): Pair<Float, Offset> {
                    val s = min(size.width / iw, size.height / ih)
                    return s to Offset((size.width - iw * s) / 2, (size.height - ih * s) / 2)
                }
                fun toImage(p: Offset): Offset {
                    val (s, o) = fit()
                    return Offset(((p.x - o.x) / s).coerceIn(0f, iw), ((p.y - o.y) / s).coerceIn(0f, ih))
                }
                if (editor.tool == Tool.Text) {
                    detectTapGestures { editor.textAt = toImage(it) }
                    return@pointerInput
                }
                var start = Offset.Zero
                detectDragGestures(
                    onDragStart = { p ->
                        start = toImage(p)
                        editor.draft = when (editor.tool) {
                            Tool.Pen -> Mark.Stroke(listOf(start), editor.color, editor.width)
                            Tool.Highlight -> Mark.Stroke(listOf(start), editor.color, editor.width * 4, highlight = true)
                            else -> null
                        }
                    },
                    onDrag = { change, _ ->
                        val p = toImage(change.position)
                        editor.draft = when (editor.tool) {
                            Tool.Pen, Tool.Highlight -> (editor.draft as? Mark.Stroke)?.let { it.copy(points = it.points + p) }
                            Tool.Arrow -> Mark.Arrow(start, p, editor.color, editor.width)
                            Tool.Box -> Mark.Box(rectOf(start, p), editor.color, editor.width)
                            Tool.Oval -> Mark.Oval(rectOf(start, p), editor.color, editor.width)
                            Tool.Pixelate -> Mark.Pixelate(rectOf(start, p))
                            Tool.Crop -> { editor.cropDraft = rectOf(start, p); null }
                            Tool.Text -> null
                        }
                    },
                    onDragEnd = {
                        if (editor.tool == Tool.Crop) {
                            doc.crop(editor.cropDraft)
                            editor.cropDraft = null
                        } else {
                            editor.draft?.let(doc::add)
                            editor.draft = null
                        }
                        editor.changed()
                    },
                )
            },
    ) {
        val s = min(size.width / iw, size.height / ih)
        val o = Offset((size.width - iw * s) / 2, (size.height - ih * s) / 2)
        fun Offset.v() = Offset(o.x + x * s, o.y + y * s)
        fun Rect.v() = Rect(topLeft.v(), Size(width * s, height * s))

        drawImage(bitmap, dstOffset = IntOffset(o.x.toInt(), o.y.toInt()), dstSize = IntSize((iw * s).toInt(), (ih * s).toInt()))

        // The shape being dragged.
        when (val d = editor.draft) {
            is Mark.Stroke -> {
                val path = Path().apply {
                    d.points.firstOrNull()?.v()?.let { moveTo(it.x, it.y) }
                    d.points.drop(1).forEach { val p = it.v(); lineTo(p.x, p.y) }
                }
                drawPath(path, d.color.copy(alpha = if (d.highlight) 0.35f else 1f), style = Stroke(d.width * s))
            }
            is Mark.Arrow -> drawLine(d.color, d.from.v(), d.to.v(), d.width * s)
            is Mark.Box -> d.rect.v().let { drawRect(d.color, it.topLeft, it.size, style = Stroke(d.width * s)) }
            is Mark.Oval -> d.rect.v().let { drawOval(d.color, it.topLeft, it.size, style = Stroke(d.width * s)) }
            is Mark.Pixelate -> d.rect.v().let { drawRect(Color.Gray.copy(alpha = 0.5f), it.topLeft, it.size) }
            else -> {}
        }

        // The crop: dim what falls outside it.
        val crop = editor.cropDraft ?: doc.current.crop
        if (crop != null) {
            val c = crop.v()
            val dim = Color.Black.copy(alpha = 0.55f)
            val img = Rect(o, Size(iw * s, ih * s))
            drawRect(dim, img.topLeft, Size(img.width, c.top - img.top))
            drawRect(dim, Offset(img.left, c.bottom), Size(img.width, img.bottom - c.bottom))
            drawRect(dim, Offset(img.left, c.top), Size(c.left - img.left, c.height))
            drawRect(dim, Offset(c.right, c.top), Size(img.right - c.right, c.height))
            drawRect(Color.White, c.topLeft, c.size, style = Stroke(2f))
        }
    }
}

@Composable
fun TextDialog(onDone: (String) -> Unit) {
    var text by remember { mutableStateOf("") }
    AlertDialog(
        onDismissRequest = { onDone("") },
        title = { Text("Add text") },
        text = { OutlinedTextField(text, { text = it }, singleLine = false, modifier = Modifier.width(360.dp).height(120.dp)) },
        confirmButton = { TextButton(onClick = { onDone(text) }) { Text("Add") } },
        dismissButton = { TextButton(onClick = { onDone("") }) { Text("Cancel") } },
    )
}
