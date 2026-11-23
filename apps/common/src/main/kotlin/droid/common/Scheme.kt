package droid.common

import androidx.compose.material3.ColorScheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.ui.graphics.Color
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.boolean
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import java.io.File

/**
 * KShell's Material 3 scheme, as `kshelld scheme` writes it to
 * ~/.local/state/kshell/scheme.json: `{"dark": true, "colors": {"primary": "#00687b", ...}}`
 * with Compose's colour role names.
 */
object Scheme {
    val file: File = File(System.getProperty("user.home"), ".local/state/kshell/scheme.json")

    /** The scheme KShell uses now, or Material's baseline when there isn't one. */
    fun load(file: File = this.file): ColorScheme =
        runCatching { parse(file.readText()) }.getOrElse { darkColorScheme() }

    fun parse(json: String): ColorScheme {
        val root = Json.parseToJsonElement(json).jsonObject
        val dark = root["dark"]?.jsonPrimitive?.boolean ?: true
        val colors = root["colors"]?.jsonObject ?: JsonObject(emptyMap())
        val base = if (dark) darkColorScheme() else lightColorScheme()
        fun c(role: String, fallback: Color) =
            colors[role]?.jsonPrimitive?.contentOrNull?.let(::hex) ?: fallback
        return base.copy(
            primary = c("primary", base.primary),
            onPrimary = c("onPrimary", base.onPrimary),
            primaryContainer = c("primaryContainer", base.primaryContainer),
            onPrimaryContainer = c("onPrimaryContainer", base.onPrimaryContainer),
            inversePrimary = c("inversePrimary", base.inversePrimary),
            secondary = c("secondary", base.secondary),
            onSecondary = c("onSecondary", base.onSecondary),
            secondaryContainer = c("secondaryContainer", base.secondaryContainer),
            onSecondaryContainer = c("onSecondaryContainer", base.onSecondaryContainer),
            tertiary = c("tertiary", base.tertiary),
            onTertiary = c("onTertiary", base.onTertiary),
            tertiaryContainer = c("tertiaryContainer", base.tertiaryContainer),
            onTertiaryContainer = c("onTertiaryContainer", base.onTertiaryContainer),
            background = c("background", base.background),
            onBackground = c("onBackground", base.onBackground),
            surface = c("surface", base.surface),
            onSurface = c("onSurface", base.onSurface),
            surfaceVariant = c("surfaceVariant", base.surfaceVariant),
            onSurfaceVariant = c("onSurfaceVariant", base.onSurfaceVariant),
            surfaceTint = c("surfaceTint", base.surfaceTint),
            inverseSurface = c("inverseSurface", base.inverseSurface),
            inverseOnSurface = c("inverseOnSurface", base.inverseOnSurface),
            error = c("error", base.error),
            onError = c("onError", base.onError),
            errorContainer = c("errorContainer", base.errorContainer),
            onErrorContainer = c("onErrorContainer", base.onErrorContainer),
            outline = c("outline", base.outline),
            outlineVariant = c("outlineVariant", base.outlineVariant),
            scrim = c("scrim", base.scrim),
            surfaceBright = c("surfaceBright", base.surfaceBright),
            surfaceDim = c("surfaceDim", base.surfaceDim),
            surfaceContainer = c("surfaceContainer", base.surfaceContainer),
            surfaceContainerHigh = c("surfaceContainerHigh", base.surfaceContainerHigh),
            surfaceContainerHighest = c("surfaceContainerHighest", base.surfaceContainerHighest),
            surfaceContainerLow = c("surfaceContainerLow", base.surfaceContainerLow),
            surfaceContainerLowest = c("surfaceContainerLowest", base.surfaceContainerLowest),
        )
    }

    /** `#rrggbb` or `#aarrggbb`. */
    fun hex(s: String): Color? {
        val v = s.removePrefix("#").toLongOrNull(16) ?: return null
        return when (s.removePrefix("#").length) {
            6 -> Color(0xFF000000 or v)
            8 -> Color(v)
            else -> null
        }
    }
}
