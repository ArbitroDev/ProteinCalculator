package arbitro.android.protein_calculator.wear

import arbitro.android.protein_calculator.protocol.WatchProduct
import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneId

/** What the watch app shows. */
sealed interface WatchScreen {
    /** The stored data is being read. */
    data object Loading : WatchScreen

    /** Nothing to show yet: the phone app never sent its day, or its first launch is not done. */
    data object OpenPhone : WatchScreen

    /** The phone and the watch do not understand each other. */
    data class Incompatible(val incompatibility: Incompatibility) : WatchScreen

    data class Day(
        /** Protein grams of the current app day, those waiting for the phone included. */
        val total: Double,
        /** Protein grams added today on the watch that the phone has not made yet. */
        val pending: Double,
        val goal: Double,
        /** Entries of the day, the most recent first, those waiting for the phone included. */
        val entries: List<DayEntry>,
        val products: List<WatchProduct>,
        /** When the phone sent this day, in milliseconds since the epoch. */
        val updatedAt: Long,
        val phoneNearby: Boolean,
    ) : WatchScreen
}

/** An entry of the day. */
data class DayEntry(
    /** Null for an entry without a name. */
    val name: String?,
    val protein: Double,
    /** When it was added, in milliseconds since the epoch. */
    val time: Long,
    /** Whether it was added on the watch. */
    val fromWatch: Boolean,
    /** Whether the phone has not made it yet: added on the watch out of its range. */
    val pending: Boolean,
)

/**
 * Screen showing [saved] at [now], in milliseconds since the epoch, in the
 * time zone [zone]. Once the app day of the state is over, the total starts
 * again from zero, without waiting for the phone. The additions waiting for
 * the phone count in the total of their day.
 */
fun watchScreenOf(saved: Saved, phoneNearby: Boolean, now: Long, zone: ZoneId): WatchScreen {
    saved.incompatibility?.let { return WatchScreen.Incompatible(it) }
    val state = saved.state ?: return WatchScreen.OpenPhone
    val goal = state.goal ?: return WatchScreen.OpenPhone
    fun dayOf(time: Long) = dayKeyOf(LocalDateTime.ofInstant(Instant.ofEpochMilli(time), zone), state.dayStartHour)
    val today = dayOf(now)
    val waiting = saved.pending.filter { dayOf(it.addedAt) == today }
    val pending = waiting.sumOf { it.protein }
    val sent = if (today > state.day) emptyList() else state.entries
    return WatchScreen.Day(
        total = (if (today > state.day) 0.0 else state.total) + pending,
        pending = pending,
        goal = goal,
        entries = (
            sent.map { DayEntry(it.name, it.protein, it.time, it.fromWatch, pending = false) } +
                waiting.map { DayEntry(it.name, it.protein, it.addedAt, fromWatch = true, pending = true) }
            ).sortedByDescending { it.time },
        products = state.products,
        updatedAt = saved.receivedAt ?: now,
        phoneNearby = phoneNearby,
    )
}
