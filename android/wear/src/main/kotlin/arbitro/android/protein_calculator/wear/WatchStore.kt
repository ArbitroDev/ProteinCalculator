package arbitro.android.protein_calculator.wear

import android.content.Context
import androidx.datastore.preferences.core.MutablePreferences
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import arbitro.android.protein_calculator.protocol.AddReply
import arbitro.android.protein_calculator.protocol.DayState
import arbitro.android.protein_calculator.protocol.Received
import arbitro.android.protein_calculator.protocol.WatchAddition
import arbitro.android.protein_calculator.protocol.WatchMessages
import arbitro.android.protein_calculator.protocol.WatchProduct
import arbitro.android.protein_calculator.protocol.WatchProtocol
import java.util.UUID
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json

private val Context.dataStore by preferencesDataStore(name = "watch")

/** Which app must be updated for the phone and the watch to understand each other. */
enum class Incompatibility { UPDATE_WATCH, UPDATE_PHONE }

/** What the watch keeps of the phone, shown even out of range. */
data class Saved(
    /** Last state of the day received from the phone. */
    val state: DayState?,
    /** When [state] was received, in milliseconds since the epoch. */
    val receivedAt: Long?,
    val incompatibility: Incompatibility?,
    /** Additions made on the watch the phone has not made yet, oldest first. */
    val pending: List<WatchAddition>,
)

/**
 * The data of the watch, stored on the watch only. Each change is written
 * at once, as a whole: an addition is never lost, even if the watch turns
 * off.
 */
class WatchStore(context: Context) {
    private val context = context.applicationContext
    private val dataStore = this.context.dataStore

    /** Changes the data, then draws again what shows it outside the app. */
    private suspend fun edit(change: (MutablePreferences) -> Unit) {
        dataStore.edit(change)
        ProteinTileService.refresh(context)
    }

    val saved: Flow<Saved> = dataStore.data.map { preferences ->
        Saved(
            state = preferences[STATE]?.let { stored ->
                (WatchMessages.decodeState(stored.encodeToByteArray()) as? Received.Message)?.value
            },
            receivedAt = preferences[RECEIVED_AT],
            incompatibility = preferences[INCOMPATIBILITY]?.let { name ->
                Incompatibility.entries.firstOrNull { it.name == name }
            },
            pending = preferences.pending,
        )
    }

    /** Additions waiting for the phone, oldest first. */
    suspend fun pending(): List<WatchAddition> = saved.first().pending

    /** Adds a portion of [product] at [now], in milliseconds since the epoch, for the phone to add. */
    suspend fun add(product: WatchProduct, now: Long): WatchAddition {
        val addition = WatchAddition(
            id = UUID.randomUUID().toString(),
            productId = product.id,
            name = product.name,
            protein = product.protein,
            addedAt = now,
        )
        edit { it.pending = it.pending + addition }
        return addition
    }

    /**
     * Keeps the state of the day in [message], received from the phone at
     * [receivedAt], or notes that the two apps do not understand each other.
     */
    suspend fun receiveState(message: ByteArray, receivedAt: Long) {
        when (val received = WatchMessages.decodeState(message)) {
            is Received.Message -> edit { it.keep(received.value, receivedAt) }
            is Received.OtherVersion -> saveIncompatibility(received.version)
            is Received.Unsupported -> saveIncompatibility(received.versions.max())
            // Not from the phone app: ignored.
            Received.Malformed -> Unit
        }
    }

    /**
     * Drops the additions the phone answered for in [message], received at
     * [receivedAt], and keeps the new state of the day. Returns whether the
     * phone answered.
     */
    suspend fun receiveAddReply(message: ByteArray, receivedAt: Long): Boolean =
        when (val received = WatchMessages.decodeAddReply(message)) {
            is Received.Message -> {
                edit { it.keep(received.value, receivedAt) }
                true
            }
            is Received.OtherVersion -> {
                saveIncompatibility(received.version)
                false
            }
            is Received.Unsupported -> {
                saveIncompatibility(received.versions.max())
                false
            }
            Received.Malformed -> false
        }

    private fun MutablePreferences.keep(reply: AddReply, receivedAt: Long) {
        val answered = reply.results.map { it.id }.toSet()
        pending = pending.filterNot { it.id in answered }
        keep(reply.state, receivedAt)
    }

    /** Keeps [state], and drops the additions it says were made. */
    private fun MutablePreferences.keep(state: DayState, receivedAt: Long) {
        // Kept as the phone writes it, read again by the protocol.
        this[STATE] = WatchMessages.encodeState(state).decodeToString()
        this[RECEIVED_AT] = receivedAt
        remove(INCOMPATIBILITY)
        val handled = state.handled.toSet()
        pending = pending.filterNot { it.id in handled }
    }

    /** Notes that the phone writes the messages of [version]. */
    private suspend fun saveIncompatibility(version: Int) {
        val incompatibility = if (version > WatchProtocol.VERSION) {
            Incompatibility.UPDATE_WATCH
        } else {
            Incompatibility.UPDATE_PHONE
        }
        edit { it[INCOMPATIBILITY] = incompatibility.name }
    }

    private companion object {
        val STATE: Preferences.Key<String> = stringPreferencesKey("state")
        val RECEIVED_AT: Preferences.Key<Long> = longPreferencesKey("receivedAt")
        val INCOMPATIBILITY: Preferences.Key<String> = stringPreferencesKey("incompatibility")
        val PENDING: Preferences.Key<String> = stringPreferencesKey("pending")

        val pendingSerializer = ListSerializer(WatchAddition.serializer())
    }

    private var MutablePreferences.pending: List<WatchAddition>
        get() = (this as Preferences).pending
        set(value) {
            this[PENDING] = Json.encodeToString(pendingSerializer, value)
        }

    private val Preferences.pending: List<WatchAddition>
        get() = this[PENDING]?.let { Json.decodeFromString(pendingSerializer, it) } ?: emptyList()
}
