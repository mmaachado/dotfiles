package droid.common

import androidx.compose.ui.graphics.Color
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class SchemeTest {
    @Test
    fun readsKShellColours() {
        val scheme = Scheme.parse("""{"dark": true, "colors": {"primary": "#00687b", "surface": "#0f1416"}}""")
        assertEquals(Color(0xFF00687B), scheme.primary)
        assertEquals(Color(0xFF0F1416), scheme.surface)
    }

    @Test
    fun keepsBaselineForMissingRoles() {
        val scheme = Scheme.parse("""{"dark": false, "colors": {}}""")
        assertEquals(androidx.compose.material3.lightColorScheme().primary, scheme.primary)
    }

    @Test
    fun parsesHex() {
        assertEquals(Color(0x80112233), Scheme.hex("#80112233"))
        assertNull(Scheme.hex("#12"))
        assertNull(Scheme.hex("nope"))
    }
}
