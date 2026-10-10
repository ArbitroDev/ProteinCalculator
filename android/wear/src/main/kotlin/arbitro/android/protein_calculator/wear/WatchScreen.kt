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
        /** Protein grams of the current app day. */
        val total: Double,
        val goal: Double,
        val products: List<WatchProduct>,
        /** When the phone sent this day, in milliseconds since the epoch. */
        val updatedAt: Long,
        val phoneNearby: Boolean,
    ) : WatchScreen
}

/**
 * Screen showing [saved] at [now], in milliseconds since the epoch, in the
 * time zone [zone]. Once the app day of the state is over, the total starts
 * again from zero, without waiting for the phone.
 */
fun watchScreenOf(saved: Saved, phoneNearby: Boolean, now: Long, zone: ZoneId): WatchScreen {
    saved.incompatibility?.let { return WatchScreen.Incompatible(it) }
    val state = saved.state ?: return WatchScreen.OpenPhone
    val goal = state.goal ?: return WatchScreen.OpenPhone
    val today = dayKeyOf(LocalDateTime.ofInstant(Instant.ofEpochMilli(now), zone), state.dayStartHour)
    return WatchScreen.Day(
        total = if (today > state.day) 0.0 else state.total,
        goal = goal,
        products = state.products,
        updatedAt = saved.receivedAt ?: now,
        phoneNearby = phoneNearby,
    )
}
