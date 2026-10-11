package arbitro.android.protein_calculator.wear

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.os.Looper
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.activity.ComponentActivity
import androidx.compose.runtime.Composable
import androidx.compose.ui.test.hasScrollToIndexAction
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollToIndex
import androidx.wear.compose.material3.TimeSource
import androidx.wear.compose.material3.TimeText
import androidx.wear.protolayout.DeviceParametersBuilders
import androidx.wear.protolayout.LayoutElementBuilders
import androidx.wear.protolayout.ResourceBuilders
import androidx.wear.protolayout.expression.VersionBuilders
import androidx.wear.protolayout.material3.materialScope
import androidx.wear.tiles.renderer.TileRenderer
import arbitro.android.protein_calculator.protocol.DayState
import arbitro.android.protein_calculator.protocol.WatchEntry
import arbitro.android.protein_calculator.protocol.WatchProduct
import java.io.File
import java.time.LocalDateTime
import java.time.ZoneId
import java.util.concurrent.Executors
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * Renders the Google Play screenshots of the watch app, in French and
 * English, with the day of the screenshots of the phone app
 * (tool/store_screenshots): the screens of the app and its tile, on a small
 * round watch of 384 x 384 pixels.
 *
 * Not a test: left out of the test tasks, it runs on demand, see
 * build.gradle.kts. The images land in tool/store_screenshots/<language>/,
 * as wear-*.png, then tool/store_screenshots/compose.py makes the store files.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [35])
class StoreScreenshotsTest {
    @get:Rule
    val compose = createAndroidComposeRule<ComponentActivity>()

    private class Texts(
        val language: String,
        /** Time at the top of the screen, as the watch shows it. */
        val time: String,
        /** Name and protein of one portion; the first one is the favorite. */
        val products: List<Pair<String, Double>>,
        /** Name, protein, hour and minute, on the current day. */
        val entries: List<Entry>,
    )

    private class Entry(val name: String, val protein: Double, val hour: Int, val minute: Int)

    private val french = Texts(
        language = "fr",
        time = "19:40",
        products = listOf(
            "Skyr nature" to 15.0,
            "Blanc de poulet" to 31.2,
            "Lentilles cuites" to 18.0,
            "Œufs" to 15.0,
            "Whey vanille" to 23.4,
        ),
        entries = listOf(
            Entry("Œufs", 15.0, 8, 10),
            Entry("Skyr nature", 15.0, 10, 30),
            Entry("Blanc de poulet", 31.2, 12, 45),
            Entry("Whey vanille", 23.4, 17, 15),
            Entry("Lentilles cuites", 18.0, 19, 20),
        ),
    )

    private val english = Texts(
        language = "en",
        time = "7:40",
        products = listOf(
            "Plain skyr" to 15.0,
            "Chicken breast" to 31.2,
            "Cooked lentils" to 18.0,
            "Eggs" to 15.0,
            "Vanilla whey" to 23.4,
        ),
        entries = listOf(
            Entry("Eggs", 15.0, 8, 10),
            Entry("Plain skyr", 15.0, 10, 30),
            Entry("Chicken breast", 31.2, 12, 45),
            Entry("Vanilla whey", 23.4, 17, 15),
            Entry("Cooked lentils", 18.0, 19, 20),
        ),
    )

    @Test
    @Config(qualifiers = "fr-rFR-$WATCH")
    fun french() = shootAll(french)

    @Test
    @Config(qualifiers = "en-rUS-$WATCH")
    fun english() = shootAll(english)

    private fun shootAll(texts: Texts) {
        val screen = watchScreenOf(saved(texts), phoneNearby = true, now = NOW, zone = ZONE)
        compose.setContent {
            WatchTheme {
                WatchApp(
                    screen = screen,
                    added = null,
                    onAdd = {},
                    onAddFree = { _, _ -> },
                    onDismissAdded = {},
                    onDelete = {},
                    onUndoDelete = {},
                    timeText = { FixedTimeText(texts.time) },
                )
            }
        }
        shoot(texts, "1-day")

        // The entries, under the summary of the day: the second one in the
        // middle of the screen, the first ones around.
        compose.onNode(hasScrollToIndexAction()).performScrollToIndex(3)
        shoot(texts, "2-entries")

        // The products, from the button below the entries.
        val add = compose.activity.getString(R.string.add)
        compose.onNode(hasScrollToIndexAction()).performScrollToIndex(texts.entries.size + 2)
        compose.onNodeWithContentDescription(add).performClick()
        shoot(texts, "3-products")

        shootTile(texts, screen, "4-tile")
    }

    /**
     * The last state of the day the phone sent, just now on the clock of the
     * computer, which the screen compares it to: as on a watch next to its
     * phone, no line says when.
     */
    private fun saved(texts: Texts): Saved {
        val products = texts.products.mapIndexed { index, (name, protein) ->
            WatchProduct(id = index + 1L, name = name, protein = protein, favorite = index == 0)
        }
        // The latest first, as the phone sends them.
        val entries = texts.entries.mapIndexed { index, entry ->
            WatchEntry(
                id = index + 1L,
                name = entry.name,
                protein = entry.protein,
                time = at(entry.hour, entry.minute),
                fromWatch = false,
            )
        }.reversed()
        val state = DayState(
            day = 20261001,
            dayStartHour = 3,
            total = texts.entries.sumOf { it.protein },
            goal = 140.0,
            entries = entries,
            products = products,
            handled = emptyList(),
        )
        return Saved(
            state = state,
            receivedAt = System.currentTimeMillis(),
            incompatibility = null,
            pending = emptyList(),
            deletions = emptyList(),
        )
    }

    private fun shoot(texts: Texts, name: String) {
        compose.waitForIdle()
        save(drawn(compose.activity.window.decorView), texts, name)
    }

    /** Measures and places [view] on the whole screen. */
    private fun layOut(view: View) {
        val size = View.MeasureSpec.makeMeasureSpec(SIZE_PX, View.MeasureSpec.EXACTLY)
        view.measure(size, size)
        view.layout(0, 0, SIZE_PX, SIZE_PX)
    }

    /** [view] drawn on an image of the screen. */
    private fun drawn(view: View): Bitmap {
        val bitmap = Bitmap.createBitmap(SIZE_PX, SIZE_PX, Bitmap.Config.ARGB_8888)
        view.draw(Canvas(bitmap))
        return bitmap
    }

    /** Draws the tile with the renderer of Wear OS, as the watch does. */
    private fun shootTile(texts: Texts, screen: WatchScreen, name: String) {
        val activity = compose.activity
        val service = Robolectric.setupService(ProteinTileService::class.java)
        val device = DeviceParametersBuilders.DeviceParameters.Builder()
            .setScreenWidthDp(SIZE_DP)
            .setScreenHeightDp(SIZE_DP)
            .setScreenDensity(DENSITY)
            .setScreenShape(DeviceParametersBuilders.SCREEN_SHAPE_ROUND)
            .setDevicePlatform(DeviceParametersBuilders.DEVICE_PLATFORM_WEAR_OS)
            .setFontScale(1f)
            // The renderer of the watches of today, protolayout 1.4: without
            // it, the layout falls back to its oldest form, a small ring.
            .setRendererSchemaVersion(
                VersionBuilders.VersionInfo.Builder().setMajor(1).setMinor(RENDERER_MINOR).build(),
            )
            .build()
        val layout = with(service) {
            materialScope(activity, device, false, ProteinTileService.tileColors) {
                layout(screen, addedId = null)
            }
        }
        // Sized before the renderer draws in it: the ring follows the edge.
        val frame = FrameLayout(activity).apply { setBackgroundColor(Color.BLACK) }
        activity.setContentView(frame, ViewGroup.LayoutParams(SIZE_PX, SIZE_PX))
        layOut(frame)
        val renderer = TileRenderer(activity, Executors.newSingleThreadExecutor()) {}
        val inflated = renderer.inflateAsync(
            LayoutElementBuilders.Layout.fromLayoutElement(layout),
            ResourceBuilders.Resources.Builder().setVersion("1").build(),
            frame,
        )
        shadowOf(Looper.getMainLooper()).idle()
        inflated.get()
        layOut(frame)
        save(drawn(frame), texts, name)
    }

    private fun save(bitmap: Bitmap, texts: Texts, name: String) {
        // Run from android/wear: the raw screenshots of the phone app are there too.
        val folder = File("../../tool/store_screenshots/${texts.language}").apply { mkdirs() }
        File(folder, "wear-$name.png").outputStream().use {
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, it)
        }
    }

    private companion object {
        /** A small round watch: 384 x 384 pixels. */
        const val WATCH = "w192dp-h192dp-small-notlong-round-watch-xhdpi-keyshidden-nonav"
        const val SIZE_DP = 192
        const val DENSITY = 2f
        const val SIZE_PX = 384
        const val RENDERER_MINOR = 403

        val ZONE: ZoneId = ZoneId.of("Europe/Paris")

        /** Thursday 1 October 2026, 7:40 p.m., as in the screenshots of the phone app. */
        val NOW = at(19, 40)

        fun at(hour: Int, minute: Int): Long =
            LocalDateTime.of(2026, 10, 1, hour, minute).atZone(ZONE).toInstant().toEpochMilli()
    }
}

/** The time at the top of the screen, fixed. */
@Composable
private fun FixedTimeText(time: String) {
    TimeText(
        timeSource = object : TimeSource {
            @Composable
            override fun currentTime(): String = time
        },
    )
}
