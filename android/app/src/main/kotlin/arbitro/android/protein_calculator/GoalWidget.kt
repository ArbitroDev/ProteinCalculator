package arbitro.android.protein_calculator

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Typeface
import android.os.Bundle
import android.widget.RemoteViews
import androidx.core.content.ContextCompat
import androidx.core.graphics.createBitmap
import es.antonborri.home_widget.HomeWidgetPlugin
import java.text.NumberFormat
import java.time.LocalDateTime
import java.time.ZoneId
import kotlin.math.cos
import kotlin.math.floor
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sin
import org.json.JSONObject

/**
 * Widget "Today's goal" of the home screen, 1 x 1: a ring filling towards
 * the goal of the day, open at the bottom, the protein total alone in its
 * middle, orange once the goal is reached, and the goal in the opening,
 * followed by a blue check once creatine is taken. An empty shaker until the
 * first launch is done. A tap opens the app. From December 1 to 25, while the
 * Christmas theme of the app is on, red in place of the orange, the check
 * fir green, a snowflake in each top corner and one above the total.
 *
 * The app writes the day each time it changes, see `updateHomeWidget` in
 * lib/core/home_widget.dart. At the hour the app days start, the widget starts
 * a new day on its own, with nothing, without waiting for the app.
 */
class GoalWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val day = Day.read(context)
        for (id in ids) manager.updateAppWidget(id, views(context, manager, id, day))
        scheduleNewDay(context, day)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        manager: AppWidgetManager,
        id: Int,
        options: Bundle,
    ) {
        manager.updateAppWidget(id, views(context, manager, id, Day.read(context)))
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_NEW_DAY) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, GoalWidget::class.java))
            if (ids.isNotEmpty()) onUpdate(context, manager, ids)
        }
    }

    override fun onDisabled(context: Context) {
        alarms(context).cancel(newDayIntent(context))
    }

    /** What the widget shows of the app day: nothing once it is over. */
    private class Day(
        val dayKey: Int,
        val dayStartHour: Int,
        val total: Double,
        val goal: Double?,
        val creatineTaken: Boolean,
        /** Whether the widget is dressed for Christmas, see [isChristmas]. */
        val christmas: Boolean,
    ) {
        companion object {
            fun read(context: Context): Day? {
                val data = HomeWidgetPlugin.getData(context)
                val json = data.getString(DAY_KEY, null) ?: return null
                // Off until the app tells the setting.
                val christmasTheme = data.getBoolean(CHRISTMAS_KEY, false)
                return try {
                    val day = JSONObject(json)
                    val dayKey = day.getInt("day")
                    val read = Day(
                        dayKey = dayKey,
                        dayStartHour = day.getInt("dayStartHour"),
                        total = day.getDouble("total"),
                        goal = if (day.isNull("goal")) null else day.getDouble("goal"),
                        creatineTaken = day.getBoolean("creatine"),
                        christmas = christmasTheme && isChristmas(dayKey),
                    )
                    // A new day started since the app wrote this one.
                    val today = currentDayKey(read.dayStartHour)
                    if (today > read.dayKey) {
                        Day(
                            today,
                            read.dayStartHour,
                            0.0,
                            read.goal,
                            false,
                            christmasTheme && isChristmas(today),
                        )
                    } else {
                        read
                    }
                } catch (_: org.json.JSONException) {
                    null
                }
            }
        }
    }

    private fun views(context: Context, manager: AppWidgetManager, id: Int, day: Day?): RemoteViews {
        val options = manager.getAppWidgetOptions(id)
        val dp = min(
            options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, DEFAULT_SIZE_DP),
            options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, DEFAULT_SIZE_DP),
        ).takeIf { it > 0 } ?: DEFAULT_SIZE_DP
        val size = (dp * context.resources.displayMetrics.density).roundToInt().coerceIn(48, 600)
        val goal = day?.goal
        return RemoteViews(context.packageName, R.layout.goal_widget).apply {
            setImageViewBitmap(R.id.goal_widget_image, draw(context, size, day))
            setContentDescription(
                R.id.goal_widget_image,
                if (day == null || goal == null) {
                    context.getString(R.string.goal_widget_open_app)
                } else {
                    listOfNotNull(
                        context.getString(
                            R.string.goal_widget_progress,
                            grams(day.total),
                            grams(goal),
                        ),
                        context.getString(R.string.goal_widget_creatine).takeIf { day.creatineTaken },
                    ).joinToString(", ")
                },
            )
            setOnClickPendingIntent(
                R.id.goal_widget_image,
                PendingIntent.getActivity(
                    context,
                    0,
                    Intent(context, AppActivity::class.java)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP),
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
                ),
            )
        }
    }

    /** The widget drawn [size] pixels wide and high. */
    private fun draw(context: Context, size: Int, day: Day?): Bitmap {
        val dark = context.resources.configuration.uiMode and
            Configuration.UI_MODE_NIGHT_MASK == Configuration.UI_MODE_NIGHT_YES
        val colors = when {
            day?.christmas == true && dark -> CHRISTMAS_DARK
            day?.christmas == true -> CHRISTMAS_LIGHT
            dark -> DARK
            else -> LIGHT
        }
        val bitmap = createBitmap(size, size)
        val canvas = Canvas(bitmap)
        val s = size.toFloat()
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)

        paint.color = colors.surface
        canvas.drawRoundRect(RectF(0f, 0f, s, s), s * 0.28f, s * 0.28f, paint)

        val goal = day?.goal
        if (day == null || goal == null) {
            // Not launched yet: the empty shaker of the logo.
            val shaker = ContextCompat.getDrawable(context, R.drawable.ic_widget_shaker)!!.mutate()
            shaker.setTint(colors.textSecondary)
            val inset = (s * 0.24f).toInt()
            shaker.setBounds(inset, inset, size - inset, size - inset)
            shaker.draw(canvas)
            return bitmap
        }

        if (day.christmas) {
            // In the top corners, clear of the ring.
            drawSnowflake(canvas, s * 0.15f, s * 0.15f, s * 0.055f, colors.snowflake)
            drawSnowflake(canvas, s * 0.86f, s * 0.14f, s * 0.04f, colors.snowflake)
            // Inside the ring, above the total.
            drawSnowflake(canvas, s * 0.5f, s * 0.27f, s * 0.045f, colors.snowflake)
        }

        val stroke = s * 0.085f
        val ring = RectF(s * 0.12f, s * 0.12f, s * 0.88f, s * 0.88f)
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = stroke
        paint.strokeCap = Paint.Cap.ROUND
        // Open at the bottom, where the goal goes.
        paint.color = colors.track
        canvas.drawArc(ring, RING_START, RING_SWEEP, false, paint)
        val progress = (round(day.total) / goal).coerceIn(0.0, 1.0)
        if (progress > 0) {
            paint.color = colors.accent
            canvas.drawArc(ring, RING_START, (RING_SWEEP * progress).toFloat(), false, paint)
        }

        paint.style = Paint.Style.FILL
        paint.textAlign = Paint.Align.CENTER
        paint.color = if (round(day.total) >= round(goal)) colors.accentText else colors.text
        paint.typeface = font(context, "SairaSemiCondensed-ExtraBold.ttf", Typeface.DEFAULT_BOLD)
        paint.textSize = s * 0.33f
        val total = grams(day.total)
        // Alone in the middle, as wide as the inside of the ring at most.
        paint.textSize = min(paint.textSize, paint.textSize * s * 0.56f / paint.measureText(total))
        canvas.drawText(total, s / 2, s * 0.5f + paint.textSize * 0.36f, paint)
        // In the opening of the ring, the goal, in the secondary color even
        // once reached, then the check of creatine, both centered.
        paint.color = colors.textSecondary
        paint.typeface = font(context, "Outfit-Medium.ttf", Typeface.DEFAULT)
        paint.textSize = s * 0.1f
        paint.textAlign = Paint.Align.LEFT
        val of = context.getString(R.string.goal_widget_of, grams(goal))
        val baseline = s * 0.88f
        val r = s * 0.045f
        val gap = s * 0.035f
        val width = paint.measureText(of) + if (day.creatineTaken) gap + 2 * r else 0f
        val left = (s - width) / 2
        canvas.drawText(of, left, baseline, paint)
        if (day.creatineTaken) {
            val cx = left + paint.measureText(of) + gap + r
            val cy = baseline - s * 0.038f
            paint.color = colors.creatine
            paint.style = Paint.Style.STROKE
            paint.strokeWidth = r * 0.3f
            paint.strokeCap = Paint.Cap.ROUND
            paint.strokeJoin = Paint.Join.ROUND
            canvas.drawCircle(cx, cy, r, paint)
            canvas.drawPath(
                Path().apply {
                    moveTo(cx - r * 0.45f, cy + r * 0.02f)
                    lineTo(cx - r * 0.1f, cy + r * 0.38f)
                    lineTo(cx + r * 0.48f, cy - r * 0.32f)
                },
                paint,
            )
        }
        return bitmap
    }

    /** A snowflake of six arms, each with two branches, of radius [r]. */
    private fun drawSnowflake(canvas: Canvas, cx: Float, cy: Float, r: Float, color: Int) {
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.color = color
            style = Paint.Style.STROKE
            strokeWidth = r * 0.3f
            strokeCap = Paint.Cap.ROUND
        }
        val path = Path()
        for (arm in 0 until 6) {
            val angle = Math.toRadians(30.0 + 60.0 * arm)
            path.moveTo(cx, cy)
            path.lineTo(cx + r * cos(angle).toFloat(), cy + r * sin(angle).toFloat())
            val mx = cx + 0.6f * r * cos(angle).toFloat()
            val my = cy + 0.6f * r * sin(angle).toFloat()
            for (side in listOf(-1, 1)) {
                val branch = angle + side * Math.toRadians(45.0)
                path.moveTo(mx, my)
                path.lineTo(
                    mx + 0.32f * r * cos(branch).toFloat(),
                    my + 0.32f * r * sin(branch).toFloat(),
                )
            }
        }
        canvas.drawPath(path, paint)
    }

    private data class Colors(
        val surface: Int,
        val track: Int,
        val text: Int,
        val textSecondary: Int,
        /** The ring, once the day has protein. */
        val accent: Int,
        val accentText: Int,
        val creatine: Int,
        val snowflake: Int = 0,
    )

    companion object {
        /** Key of the day in the storage of `home_widget`, see `homeWidgetDayKey`. */
        private const val DAY_KEY = "day"

        /** Key of the Christmas theme setting, see `homeWidgetChristmasKey`. */
        private const val CHRISTMAS_KEY = "christmasTheme"
        private const val ACTION_NEW_DAY = "arbitro.android.protein_calculator.GOAL_WIDGET_NEW_DAY"
        private const val DEFAULT_SIZE_DP = 72

        /** The ring, open at the bottom: from bottom left round to bottom right. */
        private const val RING_START = 135f
        private const val RING_SWEEP = 270f

        // The colors of the app, see lib/core/theme.dart.
        private const val ORANGE = 0xFFFF8A3D.toInt()
        private const val CHRISTMAS_RED = 0xFFD7263D.toInt()
        private val LIGHT = Colors(
            surface = 0xFFEEF2FF.toInt(),
            track = 0xFFC2CFFA.toInt(),
            text = 0xFF0F1A66.toInt(),
            textSecondary = 0xFF4A5699.toInt(),
            accent = ORANGE,
            accentText = 0xFFB8440F.toInt(),
            creatine = 0xFF1A64A3.toInt(),
        )
        private val DARK = Colors(
            surface = 0xFF1A1F3D.toInt(),
            track = 0xFF272D50.toInt(),
            text = 0xFFFFFFFF.toInt(),
            textSecondary = 0xFFA6ADDD.toInt(),
            accent = ORANGE,
            accentText = 0xFFFF8A3D.toInt(),
            creatine = 0xFF3FA9F5.toInt(),
        )

        // The Christmas themes, AppColors.christmasLight and christmasDark.
        private val CHRISTMAS_LIGHT = LIGHT.copy(
            accent = CHRISTMAS_RED,
            accentText = 0xFFB0182C.toInt(),
            creatine = 0xFF1B7A45.toInt(),
            snowflake = 0xFF8C9BEB.toInt(),
        )
        private val CHRISTMAS_DARK = DARK.copy(
            accent = CHRISTMAS_RED,
            accentText = 0xFFFF5A6A.toInt(),
            creatine = 0xFF6BD69A.toInt(),
            snowflake = 0xFFFFFFFF.toInt(),
        )

        /** Whether [dayKey] is from December 1 to 25, see `isChristmasSeason`. */
        private fun isChristmas(dayKey: Int): Boolean =
            dayKey / 100 % 100 == 12 && dayKey % 100 <= 25

        /** App day of now, as `yyyymmdd`: it starts at [dayStartHour]. */
        private fun currentDayKey(dayStartHour: Int): Int {
            val date = LocalDateTime.now().minusHours(dayStartHour.toLong()).toLocalDate()
            return date.year * 10000 + date.monthValue * 100 + date.dayOfMonth
        }

        /**
         * Whole grams, rounded as in the app (`roundGrams`): a half up. The goal
         * is reached once the total as shown reaches it (`isGoalReached`).
         */
        private fun round(grams: Double): Double = floor(grams + 0.5 + 1e-9)

        private fun grams(grams: Double): String =
            NumberFormat.getIntegerInstance().format(round(grams).toLong())

        /** Fonts of the app, read once from its assets. */
        private val fonts = mutableMapOf<String, Typeface>()

        private fun font(context: Context, name: String, fallback: Typeface): Typeface =
            fonts.getOrPut(name) {
                try {
                    Typeface.createFromAsset(context.assets, "flutter_assets/assets/fonts/$name")
                } catch (_: RuntimeException) {
                    fallback
                }
            }

        private fun alarms(context: Context) = context.getSystemService(AlarmManager::class.java)

        private fun newDayIntent(context: Context): PendingIntent = PendingIntent.getBroadcast(
            context,
            0,
            Intent(context, GoalWidget::class.java).setAction(ACTION_NEW_DAY),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        /** Updates the widgets again when the next app day starts. */
        private fun scheduleNewDay(context: Context, day: Day?) {
            val startHour = day?.dayStartHour ?: return
            val now = LocalDateTime.now()
            var next = now.toLocalDate().atTime(startHour, 0)
            if (!next.isAfter(now)) next = next.plusDays(1)
            val at = next.atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()
            // Within a few minutes after: exact alarms are kept for the reminders.
            alarms(context).setWindow(AlarmManager.RTC, at, 5 * 60 * 1000L, newDayIntent(context))
        }
    }
}
