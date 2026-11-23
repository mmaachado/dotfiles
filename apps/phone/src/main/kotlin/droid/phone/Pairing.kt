package droid.phone

import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.toComposeImageBitmap
import com.google.zxing.BarcodeFormat
import com.google.zxing.EncodeHintType
import com.google.zxing.qrcode.QRCodeWriter
import java.awt.image.BufferedImage
import kotlin.random.Random

/**
 * Wi-Fi debugging's "Pair device with QR code" (Android 11+): the QR holds
 * a service name and password; the phone then advertises
 * `_adb-tls-pairing._tcp` under that name, and we `adb pair` with it.
 */
class Pairing {
    val name = "droid-" + randomString(6)
    val password = randomString(10)

    /** The text in the QR code, in the format Android expects. */
    val payload get() = "WIFI:T:ADB;S:$name;P:$password;;"

    fun qr(size: Int = 280): ImageBitmap = qrImage(payload, size).toComposeImageBitmap()

    companion object {
        private const val ALPHABET = "abcdefghijkmnpqrstuvwxyz23456789"

        fun randomString(n: Int) = (1..n).map { ALPHABET[Random.nextInt(ALPHABET.length)] }.joinToString("")

        fun qrImage(text: String, size: Int): BufferedImage {
            val matrix = QRCodeWriter().encode(text, BarcodeFormat.QR_CODE, size, size, mapOf(EncodeHintType.MARGIN to 1))
            return BufferedImage(size, size, BufferedImage.TYPE_INT_RGB).apply {
                for (y in 0 until size) for (x in 0 until size) setRGB(x, y, if (matrix[x, y]) 0x000000 else 0xFFFFFF)
            }
        }
    }
}
