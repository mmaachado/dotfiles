package droid.markup

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import java.awt.image.BufferedImage
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotEquals
import kotlin.test.assertTrue

class RenderTest {
    private fun stripes(w: Int = 64, h: Int = 32) = BufferedImage(w, h, BufferedImage.TYPE_INT_ARGB).apply {
        for (y in 0 until h) for (x in 0 until w) setRGB(x, y, if (x % 2 == 0) 0xFFFFFFFF.toInt() else 0xFF000000.toInt())
    }

    @Test
    fun cropKeepsOnlyTheArea() {
        val doc = Document(stripes())
        doc.crop(Rect(8f, 4f, 40f, 20f))
        val out = Render.render(doc)
        assertEquals(32, out.width)
        assertEquals(16, out.height)
    }

    @Test
    fun pixelateFlattensStripes() {
        val doc = Document(stripes())
        doc.add(Mark.Pixelate(Rect(0f, 0f, 24f, 24f)))
        val out = Render.render(doc)
        assertEquals(out.getRGB(0, 0), out.getRGB(1, 0), "pixelated pixels should match")
        assertNotEquals(out.getRGB(30, 0), out.getRGB(31, 0), "outside the area stays striped")
    }

    @Test
    fun boxIsDrawnInItsColour() {
        val doc = Document(BufferedImage(40, 40, BufferedImage.TYPE_INT_ARGB))
        doc.add(Mark.Box(Rect(10f, 10f, 30f, 30f), Color.Red, 2f))
        val p = Render.render(doc).getRGB(10, 20)
        assertEquals(0xFF, (p shr 16) and 0xff)
    }

    @Test
    fun undoAndRedo() {
        val doc = Document(stripes())
        doc.add(Mark.Arrow(Offset(1f, 1f), Offset(20f, 20f), Color.Blue, 3f))
        assertTrue(doc.canUndo)
        doc.undo()
        assertEquals(0, doc.current.marks.size)
        assertTrue(doc.canRedo)
        doc.redo()
        assertEquals(1, doc.current.marks.size)
        assertFalse(doc.canRedo)
    }
}
