package droid.common

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.text.ExperimentalTextApi
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.platform.SystemFont

/** droid's system font (droid installs it; fontconfig falls back if it's missing). */
@OptIn(ExperimentalTextApi::class)
val GoogleSans = FontFamily(SystemFont("Google Sans Flex"))

private fun TextStyle.droid() = copy(fontFamily = GoogleSans)

private val droidTypography = Typography().run {
    copy(
        displayLarge = displayLarge.droid(), displayMedium = displayMedium.droid(), displaySmall = displaySmall.droid(),
        headlineLarge = headlineLarge.droid(), headlineMedium = headlineMedium.droid(), headlineSmall = headlineSmall.droid(),
        titleLarge = titleLarge.droid(), titleMedium = titleMedium.droid(), titleSmall = titleSmall.droid(),
        bodyLarge = bodyLarge.droid(), bodyMedium = bodyMedium.droid(), bodySmall = bodySmall.droid(),
        labelLarge = labelLarge.droid(), labelMedium = labelMedium.droid(), labelSmall = labelSmall.droid(),
    )
}

/** Material 3 in KShell's current colours and Google Sans, for every droid app. */
@Composable
fun DroidTheme(content: @Composable () -> Unit) {
    val colors = remember { Scheme.load() }
    MaterialTheme(colorScheme = colors, typography = droidTypography, content = content)
}
