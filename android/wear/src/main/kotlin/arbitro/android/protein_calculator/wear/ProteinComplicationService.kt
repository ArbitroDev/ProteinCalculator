package arbitro.android.protein_calculator.wear

import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.drawable.Icon
import androidx.wear.watchface.complications.data.ComplicationData
import androidx.wear.watchface.complications.data.ComplicationType
import androidx.wear.watchface.complications.data.MonochromaticImage
import androidx.wear.watchface.complications.data.NoDataComplicationData
import androidx.wear.watchface.complications.data.PlainComplicationText
import androidx.wear.watchface.complications.data.RangedValueComplicationData
import androidx.wear.watchface.complications.data.ShortTextComplicationData
import androidx.wear.watchface.complications.datasource.ComplicationDataSourceUpdateRequester
import androidx.wear.watchface.complications.datasource.ComplicationDataTimeline
import androidx.wear.watchface.complications.datasource.ComplicationRequest
import androidx.wear.watchface.complications.datasource.SuspendingTimelineComplicationDataSourceService
import androidx.wear.watchface.complications.datasource.TimeInterval
import androidx.wear.watchface.complications.datasource.TimelineEntry
import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneId
import kotlinx.coroutines.flow.first

/**
 * Progress of the day for the watch faces: a ranged value from zero to the
 * goal, or a short text "87/140". A tap opens the app. At the start of the
 * next app day, it starts again from zero without waiting for the phone,
 * and stays there the days after.
 */
class ProteinComplicationService : SuspendingTimelineComplicationDataSourceService() {
    override suspend fun onComplicationRequest(request: ComplicationRequest): ComplicationDataTimeline? {
        val saved = WatchStore(this).saved.first()
        val now = System.currentTimeMillis()
        val zone = ZoneId.systemDefault()
        val screen = watchScreenOf(saved, phoneNearby = true, now = now, zone = zone)
        if (screen !is WatchScreen.Day) {
            return ComplicationDataTimeline(NoDataComplicationData(), emptyList())
        }
        val today = data(request.complicationType, screen.total, screen.goal) ?: return null
        val dayStartHour = saved.state?.dayStartHour ?: return ComplicationDataTimeline(today, emptyList())
        val time = LocalDateTime.ofInstant(Instant.ofEpochMilli(now), zone)
        val dayEnd = nextDayStart(time, dayStartHour).atZone(zone).toInstant()
        // The total until the day ends, then zero, however long the phone
        // stays away: no other request may come meanwhile.
        val empty = data(request.complicationType, 0.0, screen.goal) ?: return null
        return ComplicationDataTimeline(
            empty,
            listOf(TimelineEntry(TimeInterval(Instant.ofEpochMilli(now), dayEnd), today)),
        )
    }

    override fun getPreviewData(type: ComplicationType): ComplicationData? = data(type, 87.0, 140.0)

    /** Data of [type] showing [total] grams of protein out of [goal]. */
    private fun data(type: ComplicationType, total: Double, goal: Double): ComplicationData? {
        val locale = resources.configuration.locales[0]
        val shownTotal = formatGrams(total, locale)
        val description = PlainComplicationText.Builder(
            getString(R.string.complication_description, shownTotal, formatGrams(goal, locale)),
        ).build()
        val icon = MonochromaticImage.Builder(Icon.createWithResource(this, R.drawable.ic_shaker)).build()
        val open = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE,
        )
        return when (type) {
            ComplicationType.RANGED_VALUE ->
                RangedValueComplicationData.Builder(
                    value = truncateGrams(total).toFloat().coerceAtMost(goal.toFloat()),
                    min = 0f,
                    max = goal.toFloat(),
                    contentDescription = description,
                )
                    .setText(PlainComplicationText.Builder(shownTotal).build())
                    .setMonochromaticImage(icon)
                    .setTapAction(open)
                    .build()
            ComplicationType.SHORT_TEXT -> {
                val text = "$shownTotal/${formatGrams(goal, locale)}"
                // A short text shows 7 characters at most.
                ShortTextComplicationData.Builder(
                    PlainComplicationText.Builder(
                        if (text.length <= 7) text else getString(R.string.grams, shownTotal),
                    ).build(),
                    description,
                )
                    .setMonochromaticImage(icon)
                    .setTapAction(open)
                    .build()
            }
            else -> null
        }
    }

    companion object {
        /** Asks the watch faces to show the complication again, after the data of the watch changed. */
        fun refresh(context: Context) {
            ComplicationDataSourceUpdateRequester
                .create(context, ComponentName(context, ProteinComplicationService::class.java))
                .requestUpdateAll()
        }
    }
}
