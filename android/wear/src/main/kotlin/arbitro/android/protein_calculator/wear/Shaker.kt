package arbitro.android.protein_calculator.wear

import androidx.compose.foundation.Canvas
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.vector.PathParser

/** Shapes of the shaker of the logo (assets/branding/logo.svg), standing up. */
private object ShakerShapes {
    // Bounds of the shapes in the coordinates of the logo.
    const val LEFT = 33f
    const val TOP = 12f
    const val WIDTH = 34f
    const val HEIGHT = 74f
    const val BODY_TOP = 40f
    const val BODY_BOTTOM = 84f

    val body = path("M37 40 L39.5 79 Q40 84 45 84 H55 Q60 84 60.5 79 L63 40 Z")
    val ring = path(
        "M36.5 31 H63.5 Q66 31 66 33.5 V38.5 Q66 41 63.5 41 H36.5 Q34 41 34 38.5 V33.5 Q34 31 36.5 31 Z",
    )
    val lid = path("M36 31 Q36 23 43 23 H57 Q64 23 64 31 Z")
    val spout = path("M41 17 H46 Q48 17 48 19 V22 Q48 24 46 24 H41 Q39 24 39 22 V19 Q39 17 41 17 Z")
    val handle = path("M55 24 V18 Q55 13 59.5 13 Q64 13 64 18 V24")

    private fun path(data: String): Path = PathParser().parsePathString(data).toPath()
}

/**
 * The shaker of the logo, filled up to [fraction] of its body (0 to 1), as
 * the shaker of the phone app fills towards the goal.
 */
@Composable
fun Shaker(fraction: Float, modifier: Modifier = Modifier) {
    Canvas(modifier) {
        val scale = minOf(size.width / ShakerShapes.WIDTH, size.height / ShakerShapes.HEIGHT)
        val left = (size.width - ShakerShapes.WIDTH * scale) / 2
        val top = (size.height - ShakerShapes.HEIGHT * scale) / 2
        translate(left - ShakerShapes.LEFT * scale, top - ShakerShapes.TOP * scale) {
            scale(scale, pivot = Offset.Zero) {
                val level = ShakerShapes.BODY_BOTTOM -
                    (ShakerShapes.BODY_BOTTOM - ShakerShapes.BODY_TOP) * fraction.coerceIn(0f, 1f)
                clipPath(ShakerShapes.body) {
                    drawRect(
                        WatchColors.accent,
                        topLeft = Offset(ShakerShapes.LEFT, level),
                        size = Size(ShakerShapes.WIDTH, ShakerShapes.BODY_BOTTOM - level),
                    )
                }
                val outline = Stroke(3.6f, join = StrokeJoin.Round)
                drawPath(ShakerShapes.body, WatchColors.shaker, style = outline)
                drawPath(ShakerShapes.ring, WatchColors.shaker)
                drawPath(ShakerShapes.lid, WatchColors.shaker)
                drawPath(ShakerShapes.spout, WatchColors.shaker)
                drawPath(ShakerShapes.handle, WatchColors.shaker, style = Stroke(2.8f))
            }
        }
    }
}
