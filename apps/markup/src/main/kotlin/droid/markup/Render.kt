package droid.markup

import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import java.awt.BasicStroke
import java.awt.Font
import java.awt.RenderingHints
import java.awt.geom.Ellipse2D
import java.awt.geom.Path2D
import java.awt.geom.Rectangle2D
import java.awt.image.BufferedImage
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.roundToInt
import kotlin.math.sin

/**
 * Draws a document with Java2D. The editor's preview and the saved file use
 * the same code, so what's on screen is what gets saved.
 */
object Render {
    /** The image with every mark; cropped too when [cropped]. */
    fun render(doc: Document, edit: Edit = doc.current, cropped: Boolean = true): BufferedImage {
        val src = doc.image
        val out = BufferedImage(src.width, src.height, BufferedImage.TYPE_INT_ARGB)
        val g = out.createGraphics()
        g.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON)
        g.setRenderingHint(RenderingHints.KEY_TEXT_ANTIALIASING, RenderingHints.VALUE_TEXT_ANTIALIAS_ON)
        g.setRenderingHint(RenderingHints.KEY_STROKE_CONTROL, RenderingHints.VALUE_STROKE_PURE)
        g.drawImage(src, 0, 0, null)
        for (mark in edit.marks) draw(g, out, mark)
        g.dispose()
        val crop = edit.crop
        if (!cropped || crop == null) return out
        val x = crop.left.roundToInt().coerceIn(0, out.width - 1)
        val y = crop.top.roundToInt().coerceIn(0, out.height - 1)
        val w = crop.width.roundToInt().coerceIn(1, out.width - x)
        val h = crop.height.roundToInt().coerceIn(1, out.height - y)
        return out.getSubimage(x, y, w, h).let { sub ->
            BufferedImage(w, h, BufferedImage.TYPE_INT_ARGB).also { it.createGraphics().apply { drawImage(sub, 0, 0, null); dispose() } }
        }
    }

    private fun awt(c: Color, alpha: Float = c.alpha) =
        java.awt.Color(c.red, c.green, c.blue, alpha)

    private fun draw(g: java.awt.Graphics2D, img: BufferedImage, mark: Mark) {
        when (mark) {
            is Mark.Stroke -> {
                if (mark.points.isEmpty()) return
                g.color = awt(mark.color, if (mark.highlight) 0.35f else mark.color.alpha)
                g.stroke = BasicStroke(mark.width, if (mark.highlight) BasicStroke.CAP_BUTT else BasicStroke.CAP_ROUND, BasicStroke.JOIN_ROUND)
                val path = Path2D.Float()
                path.moveTo(mark.points[0].x, mark.points[0].y)
                mark.points.drop(1).forEach { path.lineTo(it.x, it.y) }
                if (mark.points.size == 1) path.lineTo(mark.points[0].x + 0.1f, mark.points[0].y)
                g.draw(path)
            }
            is Mark.Arrow -> {
                g.color = awt(mark.color)
                g.stroke = BasicStroke(mark.width, BasicStroke.CAP_ROUND, BasicStroke.JOIN_ROUND)
                g.drawLine(mark.from.x.roundToInt(), mark.from.y.roundToInt(), mark.to.x.roundToInt(), mark.to.y.roundToInt())
                val angle = atan2((mark.to.y - mark.from.y).toDouble(), (mark.to.x - mark.from.x).toDouble())
                val head = max(12f, mark.width * 4)
                val tip = Path2D.Float().apply {
                    moveTo(mark.to.x, mark.to.y)
                    lineTo(mark.to.x - head * cos(angle - 0.45).toFloat(), mark.to.y - head * sin(angle - 0.45).toFloat())
                    lineTo(mark.to.x - head * cos(angle + 0.45).toFloat(), mark.to.y - head * sin(angle + 0.45).toFloat())
                    closePath()
                }
                g.fill(tip)
            }
            is Mark.Box -> {
                g.color = awt(mark.color)
                g.stroke = BasicStroke(mark.width, BasicStroke.CAP_ROUND, BasicStroke.JOIN_ROUND)
                g.draw(Rectangle2D.Float(mark.rect.left, mark.rect.top, mark.rect.width, mark.rect.height))
            }
            is Mark.Oval -> {
                g.color = awt(mark.color)
                g.stroke = BasicStroke(mark.width)
                g.draw(Ellipse2D.Float(mark.rect.left, mark.rect.top, mark.rect.width, mark.rect.height))
            }
            is Mark.Label -> {
                g.color = awt(mark.color)
                g.font = Font("Google Sans Flex", Font.BOLD, mark.size.roundToInt())
                val fm = g.fontMetrics
                mark.text.lines().forEachIndexed { i, line ->
                    g.drawString(line, mark.at.x, mark.at.y + fm.ascent + i * fm.height)
                }
            }
            is Mark.Pixelate -> pixelate(img, mark.rect)
        }
    }

    /** Blocks of averaged colour, so text in the area can't be read. */
    fun pixelate(img: BufferedImage, rect: Rect, block: Int = 12) {
        val area = rect.intersect(Rect(0f, 0f, img.width.toFloat(), img.height.toFloat()))
        if (area.width < 1 || area.height < 1) return
        val x0 = area.left.roundToInt()
        val y0 = area.top.roundToInt()
        val x1 = area.right.roundToInt()
        val y1 = area.bottom.roundToInt()
        for (by in y0 until y1 step block) for (bx in x0 until x1 step block) {
            val ex = minOf(bx + block, x1)
            val ey = minOf(by + block, y1)
            var r = 0L; var gr = 0L; var b = 0L; var n = 0
            for (y in by until ey) for (x in bx until ex) {
                val p = img.getRGB(x, y)
                r += (p shr 16) and 0xff; gr += (p shr 8) and 0xff; b += p and 0xff; n++
            }
            if (n == 0) continue
            val avg = (0xff shl 24) or ((r / n).toInt() shl 16) or ((gr / n).toInt() shl 8) or (b / n).toInt()
            for (y in by until ey) for (x in bx until ex) img.setRGB(x, y, avg)
        }
    }
}
