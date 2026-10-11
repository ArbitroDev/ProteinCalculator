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
        /** Protein grams of the current app day, the changes waiting for the phone included. */
        val total: Double,
        /** Protein grams added today on the watch that the phone has not made yet. */
        val pending: Double,
        val goal: Double,
        /** Entries of the day, the most recent first, the changes waiting for the phone included. */
        val entries: List<DayEntry>,
        val products: List<WatchProduct>,
        /** When the phone sent this day, in milliseconds since the epoch. */
        val updatedAt: Long,
        val phoneNearby: Boolean,
    ) : WatchScreen
}

/** An entry of the day. */
data class DayEntry(
    /** Id of the entry on the phone, null while the phone has not made it. */
    val entryId: Long?,
    /** Id of the addition of the watch the phone has not made yet. */
    val additionId: String?,
    /** Null for an entry without a name. */
    val name: String?,
    val protein: Double,
    /** When it was added, in milliseconds since the epoch. */
    val time: Long,
    /** Whether it was added on the watch. */
    val fromWatch: Boolean,
    /** Whether the phone has not made it yet: added on the watch out of its range. */
    val pending: Boolean,
) {
    /** Tells the entries of a list apart. */
    val key: String get() = entryId?.let { "entry $it" } ?: "addition $additionId"
}

/**
 * Screen showing [saved] at [now], in milliseconds since the epoch, in the
 * time zone [zone]. Once the app day of the state is over, the total starts
 * again from zero, without waiting for the phone. The additions waiting for
 * the phone count in the total of their day; the entries deleted, waiting
 * for the phone too, no longer show.
 */
fun watchScreenOf(saved: Saved, phoneNearby: Boolean, now: Long, zone: ZoneId): WatchScreen {
    saved.incompatibility?.let { return WatchScreen.Incompatible(it) }
    val state = saved.state ?: return WatchScreen.OpenPhone
    val goal = state.goal ?: return WatchScreen.OpenPhone
    fun dayOf(time: Long) = dayKeyOf(LocalDateTime.ofInstant(Instant.ofEpochMilli(time), zone), state.dayStartHour)
    val today = dayOf(now)
    val waiting = saved.pending.filter { dayOf(it.addedAt) == today }
    val pending = waiting.sumOf { it.protein }
    val deleted = saved.deletions.map { it.entryId }.toSet()
    val (gone, sent) = (if (today > state.day) emptyList() else state.entries).partition { it.id in deleted }
    val total = if (today > state.day) 0.0 else (state.total - gone.sumOf { it.protein }).coerceAtLeast(0.0)
    return WatchScreen.Day(
        total = total + pending,
        pending = pending,
        goal = goal,
        entries = (
            sent.map { DayEntry(it.id, null, it.name, it.protein, it.time, it.fromWatch, pending = false) } +
                waiting.map { DayEntry(null, it.id, it.name, it.protein, it.addedAt, fromWatch = true, pending = true) }
            ).sortedByDescending { it.time },
        products = state.products,
        updatedAt = saved.receivedAt ?: now,
        phoneNearby = phoneNearby,
    )
}
