package arbitro.android.protein_calculator.wear

import android.content.ComponentName
import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.wear.protolayout.ActionBuilders.launchAction
import androidx.wear.protolayout.DimensionBuilders.expand
import androidx.wear.protolayout.LayoutElementBuilders.LayoutElement
import androidx.wear.protolayout.TimelineBuilders.Timeline
import androidx.wear.protolayout.layout.box
import androidx.wear.protolayout.layout.column
import androidx.wear.protolayout.material3.ButtonColors
import androidx.wear.protolayout.material3.ColorScheme
import androidx.wear.protolayout.material3.MaterialScope
import androidx.wear.protolayout.material3.ProgressIndicatorColors
import androidx.wear.protolayout.material3.Typography
import androidx.wear.protolayout.material3.circularProgressIndicator
import androidx.wear.protolayout.material3.primaryLayout
import androidx.wear.protolayout.material3.text
import androidx.wear.protolayout.material3.textEdgeButton
import androidx.wear.protolayout.modifiers.clickable
import androidx.wear.protolayout.modifiers.loadAction
import androidx.wear.protolayout.types.LayoutColor
import androidx.wear.protolayout.types.LayoutString
import androidx.wear.tiles.Material3TileService
import androidx.wear.tiles.RequestBuilders.TileRequest
import androidx.wear.tiles.TileBuilders.Tile
import androidx.wear.tiles.TileService
import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneId
import kotlinx.coroutines.flow.first

/**
 * Tile of the day: the progress ring along the edge of the screen, the
 * total and the goal, and a button adding a portion of the favorite product,
 * if there is one. A tap elsewhere opens the app.
 */
class ProteinTileService : Material3TileService(allowDynamicTheme = false, defaultColorScheme = tileColors) {
    override suspend fun MaterialScope.tileResponse(requestParams: TileRequest): Tile {
        val store = WatchStore(this@ProteinTileService)
        val now = System.currentTimeMillis()
        val zone = ZoneId.systemDefault()
        // The button of the favorite: added at once, sent to the phone when nearby.
        favoriteIdOf(requestParams.currentState.lastClickableId)?.let { id ->
            val saved = store.saved.first()
            saved.state?.products?.firstOrNull { it.id == id }?.let { product ->
                confirmed = product.id to now + CONFIRMATION_MS
                store.add(product, now)
                SendWorker.schedule(this@ProteinTileService)
                // The button shows the addition for a moment, then the favorite again.
                val context = applicationContext
                Handler(Looper.getMainLooper()).postDelayed({ refresh(context) }, CONFIRMATION_MS)
            }
        }
        val added = confirmed?.takeIf { (_, until) -> now < until }?.first
        val saved = store.saved.first()
        val screen = watchScreenOf(saved, phoneNearby = true, now = now, zone = zone)
        val tile = Tile.Builder()
            .setResourcesVersion(RESOURCES_VERSION)
            .setTileTimeline(Timeline.fromLayoutElement(layout(screen, addedId = added)))
        // At the start of the next app day, the total starts again from zero.
        saved.state?.let { state ->
            val time = LocalDateTime.ofInstant(Instant.ofEpochMilli(now), zone)
            val next = nextDayStart(time, state.dayStartHour).atZone(zone).toInstant().toEpochMilli()
            tile.setFreshnessIntervalMillis(next - now)
        }
        return tile.build()
    }

    private fun MaterialScope.layout(screen: WatchScreen, addedId: Long?): LayoutElement {
        val open = clickable(launchAction(ComponentName(context, MainActivity::class.java)), OPEN)
        if (screen !is WatchScreen.Day) {
            return primaryLayout(
                mainSlot = { text(LayoutString(context.getString(R.string.open_phone)), maxLines = 3) },
                onClick = open,
            )
        }
        val locale = context.resources.configuration.locales[0]
        val favorite = screen.products.firstOrNull { it.favorite }
        val fraction = (screen.total / screen.goal).toFloat().coerceIn(0f, 1f)
        val content = primaryLayout(
            titleSlot = { text(LayoutString(context.getString(R.string.tile_title))) },
            mainSlot = {
                column(
                    text(
                        LayoutString(context.getString(R.string.grams, formatGrams(screen.total, locale))),
                        typography = Typography.NUMERAL_MEDIUM,
                        color = LayoutColor(TEXT),
                    ),
                    text(
                        LayoutString(context.getString(R.string.goal_of, formatGrams(screen.goal, locale))),
                        typography = Typography.BODY_SMALL,
                        color = LayoutColor(TEXT_SECONDARY),
                    ),
                )
            },
            bottomSlot = favorite?.let { product ->
                {
                    textEdgeButton(
                        onClick = clickable(loadAction(), FAVORITE_PREFIX + product.id),
                        colors = ButtonColors(
                            containerColor = LayoutColor(ACCENT),
                            labelColor = LayoutColor(ON_ACCENT),
                        ),
                    ) {
                        val label = if (addedId == product.id) {
                            "✓ " + context.getString(R.string.added, formatProtein(product.protein, locale))
                        } else {
                            "+ " + product.name
                        }
                        text(LayoutString(label))
                    }
                }
            },
            onClick = open,
        )
        // The ring opens at the bottom when the button of the favorite is there.
        val ring = circularProgressIndicator(
            staticProgress = fraction,
            startAngleDegrees = if (favorite != null) -135f else 0f,
            endAngleDegrees = if (favorite != null) 135f else 360f,
            colors = ProgressIndicatorColors(
                indicatorColor = LayoutColor(ACCENT),
                trackColor = LayoutColor(SURFACE),
            ),
            size = expand(),
        )
        return box(ring, content, width = expand(), height = expand())
    }

    companion object {
        private const val RESOURCES_VERSION = "1"
        private const val OPEN = "open"
        private const val FAVORITE_PREFIX = "favorite:"

        /** How long the button shows a portion added from the tile. */
        private const val CONFIRMATION_MS = 3_000L

        /** Product just added from the tile, and until when the button says so. */
        private var confirmed: Pair<Long, Long>? = null

        private const val TEXT = 0xFFFFFFFF.toInt()
        private const val TEXT_SECONDARY = 0xFF9EA7F0.toInt()
        private const val SURFACE = 0xFF1A1E5A.toInt()
        private const val ACCENT = 0xFFFF8A3D.toInt()
        private const val ON_ACCENT = 0xFF1B0E05.toInt()

        private val tileColors = ColorScheme(
            primary = LayoutColor(ACCENT),
            onPrimary = LayoutColor(ON_ACCENT),
            onSurface = LayoutColor(TEXT),
            onSurfaceVariant = LayoutColor(TEXT_SECONDARY),
            surfaceContainer = LayoutColor(SURFACE),
            background = LayoutColor(0xFF0B1050.toInt()),
        )

        /** Id of the favorite product whose button was tapped, if any. */
        private fun favoriteIdOf(clickableId: String): Long? =
            clickableId.takeIf { it.startsWith(FAVORITE_PREFIX) }?.removePrefix(FAVORITE_PREFIX)?.toLongOrNull()

        /** Asks Wear OS to draw the tile again, after the data of the watch changed. */
        fun refresh(context: Context) {
            TileService.getUpdater(context).requestUpdate(ProteinTileService::class.java)
        }
    }
}
