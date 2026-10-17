package arbitro.android.protein_calculator.wear

import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.remember
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.LineHeightStyle
import androidx.compose.ui.unit.sp
import androidx.wear.compose.material3.ColorScheme
import androidx.wear.compose.material3.MaterialTheme

/**
 * Colors of the "Marine" theme of the phone app (lib/core/theme.dart), on the
 * black background that Wear OS asks of apps and tiles.
 */
object WatchColors {
    val background = Color.Black
    val surface = Color(0xFF1A1F3D)
    val surfaceRaised = Color(0xFF272D50)
    val text = Color(0xFFFFFFFF)
    val textSecondary = Color(0xFFA6ADDD)
    val structure = Color(0xFF7C86DE)
    val accent = Color(0xFFFF8A3D)
    val onAccent = Color(0xFF1B0E05)

    /** Deletions, as in the phone app. */
    val danger = Color(0xFFFF5C7A)

    /** Lines of the shaker of the logo. */
    val shaker = Color(0xFFDCE3FF)

    /** Blue of creatine, as in the phone app. */
    val creatine = Color(0xFF3FA9F5)
}

/** Text styles of the app: Saira Semi Condensed for numbers, Outfit for text. */
class WatchFonts(val numbers: FontFamily, val text: FontFamily) {
    val total = TextStyle(
        fontFamily = numbers,
        fontWeight = FontWeight.ExtraBold,
        fontSize = 40.sp,
        // Without the space above and below the digits, to fit in the ring.
        lineHeight = 40.sp,
        lineHeightStyle = LineHeightStyle(LineHeightStyle.Alignment.Center, LineHeightStyle.Trim.Both),
    )
    val unit = TextStyle(fontFamily = numbers, fontWeight = FontWeight.Bold, fontSize = 18.sp)
    val value = TextStyle(fontFamily = numbers, fontWeight = FontWeight.SemiBold, fontSize = 15.sp)
    val button = TextStyle(fontFamily = text, fontWeight = FontWeight.SemiBold, fontSize = 15.sp)
    val body = TextStyle(fontFamily = text, fontWeight = FontWeight.Normal, fontSize = 14.sp)
    val caption = TextStyle(fontFamily = text, fontWeight = FontWeight.Normal, fontSize = 12.sp)
}

private val colorScheme = ColorScheme(
    primary = WatchColors.accent,
    onPrimary = WatchColors.onAccent,
    primaryContainer = WatchColors.accent,
    onPrimaryContainer = WatchColors.onAccent,
    surfaceContainer = WatchColors.surface,
    surfaceContainerLow = WatchColors.surface,
    surfaceContainerHigh = WatchColors.surfaceRaised,
    onSurface = WatchColors.text,
    onSurfaceVariant = WatchColors.textSecondary,
    outline = WatchColors.structure,
    background = WatchColors.background,
    onBackground = WatchColors.text,
)

/** Text styles of the [WatchTheme] around. */
val LocalWatchFonts = staticCompositionLocalOf<WatchFonts> { error("No WatchTheme around") }

@Composable
fun WatchTheme(content: @Composable () -> Unit) {
    val assets = LocalContext.current.assets
    val fonts = remember(assets) {
        WatchFonts(
            numbers = FontFamily(
                Font("SairaSemiCondensed-SemiBold.ttf", assets, FontWeight.SemiBold),
                Font("SairaSemiCondensed-Bold.ttf", assets, FontWeight.Bold),
                Font("SairaSemiCondensed-ExtraBold.ttf", assets, FontWeight.ExtraBold),
            ),
            text = FontFamily(
                Font("Outfit-Regular.ttf", assets, FontWeight.Normal),
                Font("Outfit-Medium.ttf", assets, FontWeight.Medium),
                Font("Outfit-SemiBold.ttf", assets, FontWeight.SemiBold),
            ),
        )
    }
    CompositionLocalProvider(LocalWatchFonts provides fonts) {
        MaterialTheme(colorScheme = colorScheme, content = content)
    }
}
