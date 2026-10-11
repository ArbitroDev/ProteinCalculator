package arbitro.android.protein_calculator.wear

import androidx.datastore.preferences.core.MutablePreferences
import androidx.datastore.preferences.core.mutablePreferencesOf
import arbitro.android.protein_calculator.protocol.AddReply
import arbitro.android.protein_calculator.protocol.AddResult
import arbitro.android.protein_calculator.protocol.AddStatus
import arbitro.android.protein_calculator.protocol.DayState
import arbitro.android.protein_calculator.protocol.DeleteReply
import arbitro.android.protein_calculator.protocol.DeleteResult
import arbitro.android.protein_calculator.protocol.DeleteStatus
import arbitro.android.protein_calculator.protocol.WatchAddition
import arbitro.android.protein_calculator.protocol.WatchDeletion
import arbitro.android.protein_calculator.protocol.WatchEntry
import arbitro.android.protein_calculator.protocol.WatchProtocol
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

class WatchDataTest {
    private val state = DayState(
        day = 20261001,
        dayStartHour = 3,
        total = 20.0,
        goal = 140.0,
        entries = emptyList(),
        products = emptyList(),
        handled = emptyList(),
    )

    private fun addition(id: String) =
        WatchAddition(id = id, productId = 4, name = "Skyr", protein = 15.0, addedAt = 1_790_000_000_000)

    /** Preferences holding [ids] waiting for the phone, in that order. */
    private fun waiting(vararg ids: String): MutablePreferences =
        mutablePreferencesOf().apply { ids.forEach { addPending(addition(it)) } }

    private val MutablePreferences.ids get() = pending.map { it.id }

    private fun deletion(id: String, entryId: Long = 5) = WatchDeletion(id = id, entryId = entryId, time = 1_790_000_000_000)

    private val MutablePreferences.deletionIds get() = deletions.map { it.id }

    @Test
    fun `nothing is saved at first`() {
        assertEquals(
            Saved(state = null, receivedAt = null, incompatibility = null, pending = emptyList(), deletions = emptyList()),
            mutablePreferencesOf().toSaved(),
        )
    }

    @Test
    fun `additions wait in the order they were made`() {
        val preferences = waiting("a1", "a2", "a3")

        assertEquals(listOf("a1", "a2", "a3"), preferences.ids)
        assertEquals(listOf(addition("a1"), addition("a2"), addition("a3")), preferences.toSaved().pending)
    }

    @Test
    fun `a state is kept with the time it came`() {
        val preferences = mutablePreferencesOf()

        preferences.keepState(state, receivedAt = 1_790_000_500_000)

        val saved = preferences.toSaved()
        assertEquals(state, saved.state)
        assertEquals(1_790_000_500_000, saved.receivedAt)
    }

    @Test
    fun `a state drops the additions the phone made, and those only`() {
        // The answer to a1 was lost: the phone says it made it.
        val preferences = waiting("a1", "a2")

        preferences.keepState(state.copy(handled = listOf("a1", "old")), receivedAt = 1)

        assertEquals(listOf("a2"), preferences.ids)
    }

    @Test
    fun `an answer drops the additions it answers for, whatever their status`() {
        val preferences = waiting("a1", "a2", "a3", "a4")
        val reply = AddReply(
            results = listOf(
                AddResult("a1", AddStatus.ADDED),
                AddResult("a2", AddStatus.DUPLICATE),
                AddResult("a3", AddStatus.INVALID),
            ),
            state = state,
        )

        preferences.keepReply(reply, receivedAt = 1)

        assertEquals(listOf("a4"), preferences.ids)
        assertEquals(state, preferences.toSaved().state)
    }

    @Test
    fun `an addition made while the answer comes stays waiting`() {
        val preferences = waiting("a1")
        preferences.addPending(addition("a2"))

        preferences.keepReply(AddReply(listOf(AddResult("a1", AddStatus.ADDED)), state), receivedAt = 1)

        assertEquals(listOf("a2"), preferences.ids)
    }

    @Test
    fun `an addition deleted before the phone made it is dropped`() {
        val preferences = waiting("a1", "a2")

        preferences.removePending("a1")

        assertEquals(listOf("a2"), preferences.ids)
    }

    @Test
    fun `deletions wait in the order they were made, once per entry`() {
        val preferences = mutablePreferencesOf()

        preferences.addDeletion(deletion("d1", entryId = 5))
        preferences.addDeletion(deletion("d2", entryId = 8))
        preferences.addDeletion(deletion("d3", entryId = 5))

        assertEquals(listOf("d1", "d2"), preferences.deletionIds)
        assertEquals(preferences.deletions, preferences.toSaved().deletions)
    }

    @Test
    fun `a state drops the deletions the phone made`() {
        val preferences = mutablePreferencesOf().apply {
            addDeletion(deletion("d1", entryId = 5))
            addDeletion(deletion("d2", entryId = 8))
        }

        preferences.keepState(state.copy(handled = listOf("d1")), receivedAt = 1)

        assertEquals(listOf("d2"), preferences.deletionIds)
    }

    @Test
    fun `an answer to deletions drops those it answers for only`() {
        val preferences = waiting("a1").apply {
            addDeletion(deletion("d1", entryId = 5))
            addDeletion(deletion("d2", entryId = 8))
            addDeletion(deletion("d3", entryId = 9))
        }
        val reply = DeleteReply(
            results = listOf(DeleteResult("d1", DeleteStatus.DELETED), DeleteResult("d2", DeleteStatus.MISSING)),
            state = state,
        )

        preferences.keepReply(reply, receivedAt = 1)

        assertEquals(listOf("d3"), preferences.deletionIds)
        assertEquals(listOf("a1"), preferences.ids)
        assertEquals(state, preferences.toSaved().state)
    }

    @Test
    fun `an incompatibility names the app to update, until a state comes`() {
        val preferences = waiting("a1")

        preferences.noteIncompatibility(WatchProtocol.VERSION + 1)
        assertEquals(Incompatibility.UPDATE_WATCH, preferences.toSaved().incompatibility)
        preferences.noteIncompatibility(WatchProtocol.VERSION - 1)
        assertEquals(Incompatibility.UPDATE_PHONE, preferences.toSaved().incompatibility)
        // The additions are kept for the phone, once updated.
        assertEquals(listOf("a1"), preferences.ids)

        preferences.keepState(state, receivedAt = 1)
        assertNull(preferences.toSaved().incompatibility)
    }

    @Test
    fun `a stored state the protocol no longer reads is forgotten`() {
        val preferences = mutablePreferencesOf(WatchKeys.STATE to """{"v":2}""")

        assertNull(preferences.toSaved().state)
    }

    /** The addition [id] as the watch lists it while it waits, tapped at [time]. */
    private fun waitingEntry(id: String, time: Long = 1_790_000_000_123) =
        DayEntry(null, id, "Skyr", 15.0, time, fromWatch = true, pending = true)

    /** An entry of the phone, at [time]. */
    private fun made(id: Long, time: Long = 1_790_000_000_000, name: String = "Skyr", fromWatch: Boolean = true) =
        WatchEntry(id = id, name = name, protein = 15.0, time = time, fromWatch = fromWatch)

    @Test
    fun `deleting an addition still waiting drops it, with nothing to tell the phone`() {
        val preferences = waiting("a1", "a2")

        assertFalse(preferences.delete(waitingEntry("a1"), deletionId = "d1"))

        assertEquals(listOf("a2"), preferences.ids)
        assertEquals(emptyList(), preferences.deletions)
    }

    @Test
    fun `deleting an entry of the phone keeps its deletion`() {
        val preferences = mutablePreferencesOf()
        val entry = DayEntry(42, null, "Skyr", 15.0, 1_790_000_000_000, fromWatch = false, pending = false)

        assertTrue(preferences.delete(entry, deletionId = "d1"))

        assertEquals(listOf(WatchDeletion("d1", 42, 1_790_000_000_000)), preferences.deletions)
    }

    @Test
    fun `an addition the phone made while its deletion could be undone is deleted as the entry it made`() {
        val preferences = waiting("a1")
        // The phone answers: it made the entry 42, at the second of the tap.
        val reply = AddReply(
            results = listOf(AddResult("a1", AddStatus.ADDED)),
            state = state.copy(entries = listOf(made(42), made(7, time = 1_789_990_000_000))),
        )
        preferences.keepReply(reply, receivedAt = 1)

        assertTrue(preferences.delete(waitingEntry("a1"), deletionId = "d1"))

        assertEquals(listOf(WatchDeletion("d1", 42, 1_790_000_000_000)), preferences.deletions)
    }

    @Test
    fun `two additions made at the same second are deleted as two entries`() {
        val preferences = mutablePreferencesOf()
        preferences.keepState(state.copy(entries = listOf(made(42), made(43))), receivedAt = 1)

        preferences.delete(waitingEntry("a1"), deletionId = "d1")
        preferences.delete(waitingEntry("a2", time = 1_790_000_000_456), deletionId = "d2")

        assertEquals(setOf(42L, 43L), preferences.deletions.map { it.entryId }.toSet())
    }

    @Test
    fun `an addition made at the time of the phone, the watch running ahead, is found by its name`() {
        val preferences = mutablePreferencesOf()
        preferences.keepState(state.copy(entries = listOf(made(42, time = 1_789_999_950_000))), receivedAt = 1)

        assertTrue(preferences.delete(waitingEntry("a1"), deletionId = "d1"))

        assertEquals(listOf(42L), preferences.deletions.map { it.entryId })
    }

    @Test
    fun `an addition the phone refused deletes no other entry`() {
        val preferences = mutablePreferencesOf()
        // Of the morning, or not added on the watch.
        preferences.keepState(
            state.copy(entries = listOf(made(7, time = 1_789_990_000_000), made(8, fromWatch = false))),
            receivedAt = 1,
        )

        assertFalse(preferences.delete(waitingEntry("a1"), deletionId = "d1"))

        assertEquals(emptyList(), preferences.deletions)
    }
}
