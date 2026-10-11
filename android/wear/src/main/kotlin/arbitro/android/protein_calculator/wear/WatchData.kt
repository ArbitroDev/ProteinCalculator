package arbitro.android.protein_calculator.wear

import androidx.datastore.preferences.core.MutablePreferences
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import arbitro.android.protein_calculator.protocol.AddReply
import arbitro.android.protein_calculator.protocol.DayState
import arbitro.android.protein_calculator.protocol.DeleteReply
import arbitro.android.protein_calculator.protocol.Received
import arbitro.android.protein_calculator.protocol.WatchAddition
import arbitro.android.protein_calculator.protocol.WatchDeletion
import arbitro.android.protein_calculator.protocol.WatchMessages
import arbitro.android.protein_calculator.protocol.WatchProtocol
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json

/**
 * How the data of the watch is stored, apart from [WatchStore] so it can be
 * checked without a watch: the last state of the day, when it came, and the
 * additions and deletions waiting for the phone.
 */
internal object WatchKeys {
    val STATE: Preferences.Key<String> = stringPreferencesKey("state")
    val RECEIVED_AT: Preferences.Key<Long> = longPreferencesKey("receivedAt")
    val INCOMPATIBILITY: Preferences.Key<String> = stringPreferencesKey("incompatibility")
    val PENDING: Preferences.Key<String> = stringPreferencesKey("pending")
    val DELETIONS: Preferences.Key<String> = stringPreferencesKey("deletions")
}

private val pendingSerializer = ListSerializer(WatchAddition.serializer())
private val deletionsSerializer = ListSerializer(WatchDeletion.serializer())

/** What the watch keeps, read from its stored preferences. */
internal fun Preferences.toSaved() = Saved(
    state = this[WatchKeys.STATE]?.let { stored ->
        (WatchMessages.decodeState(stored.encodeToByteArray()) as? Received.Message)?.value
    },
    receivedAt = this[WatchKeys.RECEIVED_AT],
    incompatibility = this[WatchKeys.INCOMPATIBILITY]?.let { name ->
        Incompatibility.entries.firstOrNull { it.name == name }
    },
    pending = pending,
    deletions = deletions,
)

/** Additions waiting for the phone, oldest first. */
internal val Preferences.pending: List<WatchAddition>
    get() = this[WatchKeys.PENDING]?.let { Json.decodeFromString(pendingSerializer, it) } ?: emptyList()

private fun MutablePreferences.setPending(additions: List<WatchAddition>) {
    this[WatchKeys.PENDING] = Json.encodeToString(pendingSerializer, additions)
}

/** Adds [addition] after the ones waiting already. */
internal fun MutablePreferences.addPending(addition: WatchAddition) {
    setPending(pending + addition)
}

/** Drops the addition [id] before the phone makes it: deleted on the watch. */
internal fun MutablePreferences.removePending(id: String) {
    setPending(pending.filterNot { it.id == id })
}

/** Deletions waiting for the phone, oldest first. */
internal val Preferences.deletions: List<WatchDeletion>
    get() = this[WatchKeys.DELETIONS]?.let { Json.decodeFromString(deletionsSerializer, it) } ?: emptyList()

private fun MutablePreferences.setDeletions(deletions: List<WatchDeletion>) {
    this[WatchKeys.DELETIONS] = Json.encodeToString(deletionsSerializer, deletions)
}

/** Adds [deletion] after the ones waiting already, once per entry. */
internal fun MutablePreferences.addDeletion(deletion: WatchDeletion) {
    if (deletions.none { it.entryId == deletion.entryId }) setDeletions(deletions + deletion)
}

/**
 * Keeps [state], received at [receivedAt], and drops the additions and
 * deletions it says the phone made: their answer was lost.
 */
internal fun MutablePreferences.keepState(state: DayState, receivedAt: Long) {
    // Kept as the phone writes it, read again by the protocol.
    this[WatchKeys.STATE] = WatchMessages.encodeState(state).decodeToString()
    this[WatchKeys.RECEIVED_AT] = receivedAt
    remove(WatchKeys.INCOMPATIBILITY)
    val handled = state.handled.toSet()
    setPending(pending.filterNot { it.id in handled })
    setDeletions(deletions.filterNot { it.id in handled })
}

/** Drops the additions [reply] answers for, and keeps its state of the day. */
internal fun MutablePreferences.keepReply(reply: AddReply, receivedAt: Long) {
    val answered = reply.results.map { it.id }.toSet()
    setPending(pending.filterNot { it.id in answered })
    keepState(reply.state, receivedAt)
}

/** Drops the deletions [reply] answers for, and keeps its state of the day. */
internal fun MutablePreferences.keepReply(reply: DeleteReply, receivedAt: Long) {
    val answered = reply.results.map { it.id }.toSet()
    setDeletions(deletions.filterNot { it.id in answered })
    keepState(reply.state, receivedAt)
}

/** Notes that the phone writes or reads the messages of [version] only. */
internal fun MutablePreferences.noteIncompatibility(version: Int) {
    this[WatchKeys.INCOMPATIBILITY] = incompatibilityWith(version).name
}

/** Which app to update when the phone speaks [version] and the watch another one. */
internal fun incompatibilityWith(version: Int): Incompatibility =
    if (version > WatchProtocol.VERSION) Incompatibility.UPDATE_WATCH else Incompatibility.UPDATE_PHONE
