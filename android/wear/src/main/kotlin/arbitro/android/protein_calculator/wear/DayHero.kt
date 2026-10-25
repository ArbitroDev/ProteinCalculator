package arbitro.android.protein_calculator.wear

import android.text.format.DateUtils
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.requiredSize
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.GraphicsLayerScope
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.util.lerp
import androidx.wear.compose.foundation.lazy.TransformingLazyColumnItemScope
import androidx.wear.compose.foundation.lazy.TransformingLazyColumnItemScrollProgress
import androidx.wear.compose.material3.Text

/** How long a state stays "up to date" when the phone is nearby. */
private const val FRESH_MS = 2 * DateUtils.MINUTE_IN_MILLIS

/** Size of the summary once shrunk, against the screen. */
private const val SHRUNK_SCALE = 0.72f

/** Scrolling over which the summary shrinks, against the height of the screen. */
const val HERO_COLLAPSE = 0.3f

/** Opening of the ring at the top, along the edge of the screen, for the time. */
private const val TIME_GAP_DEGREES = 56f

private val RING_STROKE = 7.dp

/** How much closer to the shrunk ring the title of the products comes. */
private val PRODUCTS_CLOSER = 10.dp

/** Margin between the ring and the edge of the screen. */
private val RING_MARGIN = 2.dp

/**
 * How far the summary has shrunk, from 0 (the list at the top, the ring
 * along the edge of the screen) to 1, and how far it is held in place, in
 * pixels, for the scroll [progress] of its item in a list as high as
 * [viewport] pixels.
 */
private fun heroShrink(progress: TransformingLazyColumnItemScrollProgress, viewport: Float): Pair<Float, Float> {
    if (progress.isUnspecified) return 0f to 0f
    val collapse = viewport * HERO_COLLAPSE
    val held = (-progress.topOffsetFraction * viewport).coerceIn(0f, collapse)
    return held / collapse to held
}

/**
 * Summary of the day, as high as the screen: the progress ring along its
 * edge, the shaker, the total and the goal inside. As the list scrolls, it
 * stays in place and shrinks as a whole, the details fading out, then
 * scrolls away above the products.
 */
@Composable
fun TransformingLazyColumnItemScope.DayHero(day: WatchScreen.Day, viewportWidth: Dp, viewportHeight: Dp) {
    val fonts = LocalWatchFonts.current
    val locale = LocalConfiguration.current.locales[0]
    val viewport = with(LocalDensity.current) { viewportHeight.toPx() }
    val closer = with(LocalDensity.current) { PRODUCTS_CLOSER.toPx() }
    val fraction = (day.total / day.goal).toFloat().coerceIn(0f, 1f)
    val left = truncateGrams(day.goal) - truncateGrams(day.total)
    val details = Modifier.graphicsLayer {
        alpha = (1f - heroShrink(scrollProgress, viewport).first * 2).coerceAtLeast(0f)
    }
    Box(
        modifier = Modifier
            // The whole screen, beyond the side padding of the list: the ring
            // runs along the edge of the screen.
            .requiredSize(viewportWidth, viewportHeight)
            // The item takes the height of the shrunk summary, plus the
            // scrolling it is held in place for.
            .transformedHeight { height, progress ->
                val (shrink, held) = heroShrink(progress, viewport)
                // The products come a little under the ring, against the
                // space around the header.
                (height * lerp(1f, SHRUNK_SCALE, shrink) + held - closer * shrink).toInt()
            }
            .graphicsLayer { shrinkHero(scrollProgress, viewport) },
        contentAlignment = Alignment.Center,
    ) {
        val density = LocalDensity.current
        Canvas(Modifier.fillMaxSize()) {
            val shrink = heroShrink(scrollProgress, viewport).first
            val stroke = with(density) { RING_STROKE.toPx() }
            val radius = size.minDimension / 2 - stroke / 2 - with(density) { RING_MARGIN.toPx() }
            val topLeft = Offset(center.x - radius, center.y - radius)
            val arcSize = Size(radius * 2, radius * 2)
            // Along the edge, the ring opens at the top around the time.
            val gap = lerp(TIME_GAP_DEGREES, 0f, shrink)
            val start = -90f + gap / 2
            drawArc(
                WatchColors.surface,
                startAngle = start,
                sweepAngle = 360f - gap,
                useCenter = false,
                topLeft = topLeft,
                size = arcSize,
                style = Stroke(stroke, cap = StrokeCap.Round),
            )
            if (fraction > 0f) {
                drawArc(
                    WatchColors.accent,
                    startAngle = start,
                    sweepAngle = (360f - gap) * fraction,
                    useCenter = false,
                    topLeft = topLeft,
                    size = arcSize,
                    style = Stroke(stroke, cap = StrokeCap.Round),
                )
            }
        }
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Shaker(fraction, Modifier.size(width = 19.dp, height = 31.dp))
            Row(verticalAlignment = Alignment.Bottom) {
                Text(formatGrams(day.total, locale), style = fonts.total, color = WatchColors.text)
                Text(
                    " " + stringResource(R.string.grams_unit),
                    style = fonts.unit,
                    color = WatchColors.text,
                    modifier = Modifier.padding(bottom = 7.dp),
                )
            }
            // Out of range, a line more: the lines get smaller to fit in the ring.
            val goalStyle = if (day.phoneNearby) fonts.body else fonts.body.copy(fontSize = 13.sp)
            val lineStyle = if (day.phoneNearby) fonts.caption else fonts.caption.copy(fontSize = 11.sp)
            // Closer to the total than the line height of its large digits.
            Column(
                modifier = Modifier.offset(y = (-6).dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                // The creatine and the workouts of the day follow the goal.
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    Text(
                        stringResource(R.string.goal_of, formatGrams(day.goal, locale)),
                        style = goalStyle,
                        color = WatchColors.textSecondary,
                    )
                    DayMarks(day, lineStyle)
                }
                Text(
                    if (left <= 0) {
                        stringResource(R.string.goal_reached)
                    } else {
                        stringResource(R.string.remaining, formatGrams(left.toDouble(), locale))
                    },
                    style = lineStyle,
                    color = if (left <= 0) WatchColors.accent else WatchColors.textSecondary,
                    textAlign = TextAlign.Center,
                    modifier = details,
                )
                Status(day, lineStyle, details)
            }
        }
    }
}

/** Holds the summary in place and shrinks it, from its top. */
private fun GraphicsLayerScope.shrinkHero(
    progress: TransformingLazyColumnItemScrollProgress,
    viewport: Float,
) {
    val (shrink, held) = heroShrink(progress, viewport)
    val scale = lerp(1f, SHRUNK_SCALE, shrink)
    transformOrigin = TransformOrigin(0.5f, 0f)
    scaleX = scale
    scaleY = scale
    translationY = held
}

/**
 * One line, to fit in the ring: when the phone is away, since when the day
 * shown dates; otherwise the additions not sent yet, if any; otherwise when
 * the phone sent the day, unless it did just now.
 */
@Composable
private fun Status(day: WatchScreen.Day, style: TextStyle, modifier: Modifier) {
    if (day.phoneNearby && day.pending > 0) {
        val locale = LocalConfiguration.current.locales[0]
        Text(
            stringResource(R.string.pending, formatProtein(day.pending, locale)),
            style = style,
            color = WatchColors.accent,
            textAlign = TextAlign.Center,
            modifier = modifier,
        )
        return
    }
    val now = System.currentTimeMillis()
    if (day.phoneNearby && now - day.updatedAt < FRESH_MS) return
    val context = LocalContext.current
    val time = DateUtils.formatDateTime(
        context,
        day.updatedAt,
        if (DateUtils.isToday(day.updatedAt)) {
            DateUtils.FORMAT_SHOW_TIME
        } else {
            DateUtils.FORMAT_SHOW_DATE or DateUtils.FORMAT_ABBREV_MONTH or DateUtils.FORMAT_SHOW_TIME
        },
    )
    Text(
        if (day.phoneNearby) {
            stringResource(R.string.updated_at, time)
        } else {
            stringResource(R.string.phone_away_since, time)
        },
        style = style,
        color = if (day.phoneNearby) WatchColors.textSecondary else WatchColors.accent,
        textAlign = TextAlign.Center,
        modifier = modifier,
    )
}
