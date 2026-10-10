package arbitro.android.protein_calculator.wear

import androidx.datastore.preferences.core.MutablePreferences
import androidx.datastore.preferences.core.mutablePreferencesOf
import arbitro.android.protein_calculator.protocol.AddReply
import arbitro.android.protein_calculator.protocol.AddResult
import arbitro.android.protein_calculator.protocol.AddStatus
import arbitro.android.protein_calculator.protocol.DayState
import arbitro.android.protein_calculator.protocol.WatchAddition
import arbitro.android.protein_calculator.protocol.WatchProtocol
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

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

    @Test
    fun `nothing is saved at first`() {
        assertEquals(
            Saved(state = null, receivedAt = null, incompatibility = null, pending = emptyList()),
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
}
