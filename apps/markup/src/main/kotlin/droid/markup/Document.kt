package droid.markup

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import java.awt.image.BufferedImage

/** One annotation, in the image's own pixel coordinates. */
sealed interface Mark {
    data class Stroke(val points: List<Offset>, val color: Color, val width: Float, val highlight: Boolean = false) : Mark
    data class Arrow(val from: Offset, val to: Offset, val color: Color, val width: Float) : Mark
    data class Box(val rect: Rect, val color: Color, val width: Float) : Mark
    data class Oval(val rect: Rect, val color: Color, val width: Float) : Mark
    data class Label(val at: Offset, val text: String, val color: Color, val size: Float) : Mark
    data class Pixelate(val rect: Rect) : Mark
}

/** What can be undone: the marks and the crop. */
data class Edit(val marks: List<Mark> = emptyList(), val crop: Rect? = null)

/** An image being annotated, with undo and redo. */
class Document(val image: BufferedImage) {
    var current = Edit()
        private set
    private val undoStack = ArrayDeque<Edit>()
    private val redoStack = ArrayDeque<Edit>()

    val canUndo get() = undoStack.isNotEmpty()
    val canRedo get() = redoStack.isNotEmpty()
    val bounds get() = Rect(0f, 0f, image.width.toFloat(), image.height.toFloat())

    private fun change(next: Edit) {
        undoStack.addLast(current)
        redoStack.clear()
        current = next
    }

    fun add(mark: Mark) = change(current.copy(marks = current.marks + mark))

    fun crop(rect: Rect?) = change(current.copy(crop = rect?.intersect(bounds)?.takeIf { it.width >= 4 && it.height >= 4 }))

    fun undo() {
        if (canUndo) {
            redoStack.addLast(current)
            current = undoStack.removeLast()
        }
    }

    fun redo() {
        if (canRedo) {
            undoStack.addLast(current)
            current = redoStack.removeLast()
        }
    }
}

/** A rectangle from two corners, whichever way they were dragged. */
fun rectOf(a: Offset, b: Offset) = Rect(minOf(a.x, b.x), minOf(a.y, b.y), maxOf(a.x, b.x), maxOf(a.y, b.y))
