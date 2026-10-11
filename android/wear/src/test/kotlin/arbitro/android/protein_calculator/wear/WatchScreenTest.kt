package arbitro.android.protein_calculator.wear

import arbitro.android.protein_calculator.protocol.DayState
import arbitro.android.protein_calculator.protocol.WatchAddition
import arbitro.android.protein_calculator.protocol.WatchDeletion
import arbitro.android.protein_calculator.protocol.WatchEntry
import arbitro.android.protein_calculator.protocol.WatchProduct
import java.time.LocalDateTime
import java.time.ZoneId
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs

class WatchScreenTest {
    private val zone = ZoneId.of("Europe/Paris")

    private fun at(day: Int, hour: Int, minute: Int = 0): Long =
        LocalDateTime.of(2026, 10, day, hour, minute).atZone(zone).toInstant().toEpochMilli()

    private val product = WatchProduct(id = 4, name = "Skyr", protein = 15.0, favorite = true)

    private val state = DayState(
        day = 20261001,
        dayStartHour = 3,
        total = 32.5,
        goal = 140.0,
        entries = listOf(
            WatchEntry(id = 8, name = null, protein = 12.5, time = at(1, 12), fromWatch = true),
            WatchEntry(id = 5, name = "Oeufs", protein = 20.0, time = at(1, 8), fromWatch = false),
        ),
        products = listOf(product),
        handled = emptyList(),
    )

    private fun addition(id: String, addedAt: Long) =
        WatchAddition(id = id, productId = 4, name = "Skyr", protein = 15.0, addedAt = addedAt)

    private fun saved(
        state: DayState? = this.state,
        pending: List<WatchAddition> = emptyList(),
        deletions: List<WatchDeletion> = emptyList(),
        incompatibility: Incompatibility? = null,
    ) = Saved(
        state = state,
        receivedAt = at(1, 12, 5),
        incompatibility = incompatibility,
        pending = pending,
        deletions = deletions,
    )

    private fun screen(saved: Saved, now: Long = at(1, 14), phoneNearby: Boolean = true) =
        watchScreenOf(saved, phoneNearby, now, zone)

    @Test
    fun `shows the day sent by the phone`() {
        assertEquals(
            WatchScreen.Day(
                total = 32.5,
                pending = 0.0,
                goal = 140.0,
                entries = listOf(
                    DayEntry(8, null, null, 12.5, at(1, 12), fromWatch = true, pending = false),
                    DayEntry(5, null, "Oeufs", 20.0, at(1, 8), fromWatch = false, pending = false),
                ),
                products = listOf(product),
                updatedAt = at(1, 12, 5),
                phoneNearby = false,
            ),
            screen(saved(), phoneNearby = false),
        )
    }

    @Test
    fun `asks to open the phone app until it sent a day with a goal`() {
        assertEquals(WatchScreen.OpenPhone, screen(saved(state = null)))
        assertEquals(WatchScreen.OpenPhone, screen(saved(state = state.copy(goal = null))))
    }

    @Test
    fun `tells which app to update when they do not understand each other`() {
        assertEquals(
            WatchScreen.Incompatible(Incompatibility.UPDATE_PHONE),
            screen(saved(incompatibility = Incompatibility.UPDATE_PHONE)),
        )
    }

    @Test
    fun `counts the additions waiting for the phone in the day, in time order`() {
        val day = assertIs<WatchScreen.Day>(screen(saved(pending = listOf(addition("a1", at(1, 13))))))

        assertEquals(47.5, day.total)
        assertEquals(15.0, day.pending)
        assertEquals(DayEntry(null, "a1", "Skyr", 15.0, at(1, 13), fromWatch = true, pending = true), day.entries.first())
        assertEquals(3, day.entries.size)
    }

    @Test
    fun `starts again from zero once the day is over`() {
        // The next day starts at 3 a.m.: only the addition made then counts.
        val day = assertIs<WatchScreen.Day>(
            screen(
                saved(pending = listOf(addition("a1", at(1, 13)), addition("a2", at(2, 8)))),
                now = at(2, 9),
            ),
        )

        assertEquals(15.0, day.total)
        assertEquals(15.0, day.pending)
        assertEquals(listOf(at(2, 8)), day.entries.map { it.time })
        assertEquals(140.0, day.goal)
    }

    @Test
    fun `hides the entries deleted on the watch, waiting for the phone`() {
        val day = assertIs<WatchScreen.Day>(
            screen(saved(deletions = listOf(WatchDeletion(id = "d1", entryId = 5, time = at(1, 8))))),
        )

        assertEquals(12.5, day.total)
        assertEquals(listOf(8L), day.entries.map { it.entryId })
    }

    @Test
    fun `tells the entries apart, sent or waiting`() {
        val day = assertIs<WatchScreen.Day>(screen(saved(pending = listOf(addition("a1", at(1, 13))))))

        assertEquals(listOf("addition a1", "entry 8", "entry 5"), day.entries.map { it.key })
    }

    @Test
    fun `keeps the day until the hour it ends`() {
        val day = assertIs<WatchScreen.Day>(screen(saved(), now = at(2, 2, 59)))

        assertEquals(32.5, day.total)
    }
}
