package arbitro.android.protein_calculator.wear

import android.content.ComponentName
import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.annotation.DrawableRes
import androidx.compose.ui.graphics.toArgb
import androidx.wear.protolayout.ActionBuilders.launchAction
import androidx.wear.protolayout.DimensionBuilders.dp
import androidx.wear.protolayout.DimensionBuilders.expand
import androidx.wear.protolayout.LayoutElementBuilders.LayoutElement
import androidx.wear.protolayout.ResourceBuilders.AndroidImageResourceByResId
import androidx.wear.protolayout.ResourceBuilders.ImageResource
import androidx.wear.protolayout.TimelineBuilders.Timeline
import androidx.wear.protolayout.layout.box
import androidx.wear.protolayout.layout.column
import androidx.wear.protolayout.layout.row
import androidx.wear.protolayout.layout.spacer
import androidx.wear.protolayout.material3.ButtonColors
import androidx.wear.protolayout.material3.ColorScheme
import androidx.wear.protolayout.material3.MaterialScope
import androidx.wear.protolayout.material3.ProgressIndicatorColors
import androidx.wear.protolayout.material3.Typography
import androidx.wear.protolayout.material3.circularProgressIndicator
import androidx.wear.protolayout.material3.icon
import androidx.wear.protolayout.material3.primaryLayout
import androidx.wear.protolayout.material3.text
import androidx.wear.protolayout.material3.textEdgeButton
import androidx.wear.protolayout.modifiers.LayoutModifier
import androidx.wear.protolayout.modifiers.clickable
import androidx.wear.protolayout.modifiers.contentDescription
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

    /**
     * Marks of the day, as in the app: the creatine doses taken and the Hevy
     * workouts, each with their number when there are several. Nothing for
     * what the day has none of.
     */
    private fun MaterialScope.marks(screen: WatchScreen.Day): Array<LayoutElement> {
        val marks = buildList<LayoutElement> {
            if (screen.creatineDoses > 0) {
                add(
                    countMark(
                        R.drawable.ic_creatine,
                        WatchColors.creatine.toArgb(),
                        screen.creatineDoses,
                        context.resources.getQuantityString(
                            R.plurals.creatine_doses,
                            screen.creatineDoses,
                            screen.creatineDoses,
                        ),
                    ),
                )
            }
            if (screen.hevyWorkouts > 0) {
                if (isNotEmpty()) add(spacer(width = dp(MARK_GAP)))
                add(
                    countMark(
                        R.drawable.ic_dumbbell,
                        WatchColors.hevy.toArgb(),
                        screen.hevyWorkouts,
                        context.resources.getQuantityString(
                            R.plurals.hevy_workouts,
                            screen.hevyWorkouts,
                            screen.hevyWorkouts,
                        ),
                    ),
                )
            }
        }
        return if (marks.isEmpty()) emptyArray() else arrayOf(row(*marks.toTypedArray()))
    }

    /** [drawable] in [color], then "×N" when [count] is above one, read as [description]. */
    private fun MaterialScope.countMark(@DrawableRes drawable: Int, color: Int, count: Int, description: String): LayoutElement {
        val image = ImageResource.Builder()
            .setAndroidResourceByResId(AndroidImageResourceByResId.Builder().setResourceId(drawable).build())
            .build()
        val mark = icon(image, width = dp(MARK_SIZE), height = dp(MARK_SIZE), tintColor = LayoutColor(color))
        val parts = if (count > 1) {
            arrayOf(mark, text(LayoutString("×$count"), typography = Typography.BODY_SMALL, color = LayoutColor(color)))
        } else {
            arrayOf(mark)
        }
        return row(*parts, modifier = LayoutModifier.contentDescription(description))
    }

    /** Layout of the tile showing [screen]; also drawn by the store screenshots. */
    internal fun MaterialScope.layout(screen: WatchScreen, addedId: Long?): LayoutElement {
        val open = clickable(launchAction(ComponentName(context, MainActivity::class.java)), OPEN)
        if (screen !is WatchScreen.Day) {
            val message = when ((screen as? WatchScreen.Incompatible)?.incompatibility) {
                Incompatibility.UPDATE_WATCH -> R.string.update_watch
                Incompatibility.UPDATE_PHONE -> R.string.update_phone
                null -> R.string.open_phone
            }
            return primaryLayout(
                mainSlot = { text(LayoutString(context.getString(message)), maxLines = 3) },
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
                    *marks(screen),
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

        /** Size of the marks of the day, and the space between them, in dp. */
        private const val MARK_SIZE = 14f
        private const val MARK_GAP = 8f
        private const val OPEN = "open"
        private const val FAVORITE_PREFIX = "favorite:"

        /** How long the button shows a portion added from the tile. */
        private const val CONFIRMATION_MS = 3_000L

        /** Product just added from the tile, and until when the button says so. */
        private var confirmed: Pair<Long, Long>? = null

        // The colors of the app.
        private val TEXT = WatchColors.text.toArgb()
        private val TEXT_SECONDARY = WatchColors.textSecondary.toArgb()
        private val SURFACE = WatchColors.surface.toArgb()
        private val ACCENT = WatchColors.accent.toArgb()
        private val ON_ACCENT = WatchColors.onAccent.toArgb()

        internal val tileColors = ColorScheme(
            primary = LayoutColor(ACCENT),
            onPrimary = LayoutColor(ON_ACCENT),
            onSurface = LayoutColor(TEXT),
            onSurfaceVariant = LayoutColor(TEXT_SECONDARY),
            surfaceContainer = LayoutColor(SURFACE),
            background = LayoutColor(WatchColors.background.toArgb()),
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
