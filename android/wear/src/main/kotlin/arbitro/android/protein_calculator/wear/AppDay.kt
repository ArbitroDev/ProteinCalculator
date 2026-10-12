package arbitro.android.protein_calculator.wear

import java.time.LocalDate
import java.time.LocalDateTime

/**
 * App day of [time] as `yyyymmdd`. As in the phone app
 * (lib/core/domain/app_day.dart), an app day runs from [startHour] to the
 * same hour the next calendar day.
 */
fun dayKeyOf(time: LocalDateTime, startHour: Int): Int {
    val date = if (time.hour < startHour) time.toLocalDate().minusDays(1) else time.toLocalDate()
    return date.year * 10000 + date.monthValue * 100 + date.dayOfMonth
}

/** Moment the app day following the one containing [time] starts. */
fun nextDayStart(time: LocalDateTime, startHour: Int): LocalDateTime {
    val day = dayKeyOf(time, startHour)
    return LocalDate.of(day / 10000, day / 100 % 100, day % 100)
        .plusDays(1)
        .atTime(startHour, 0)
}
