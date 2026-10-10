package arbitro.android.protein_calculator.wear

import android.content.Context
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import arbitro.android.protein_calculator.protocol.DayState
import arbitro.android.protein_calculator.protocol.Received
import arbitro.android.protein_calculator.protocol.WatchMessages
import arbitro.android.protein_calculator.protocol.WatchProtocol
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

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
)

/** The data of the watch, stored on the watch only. */
class WatchStore(context: Context) {
    private val dataStore = context.applicationContext.dataStore

    val saved: Flow<Saved> = dataStore.data.map { preferences ->
        Saved(
            state = preferences[STATE]?.let { stored ->
                (WatchMessages.decodeState(stored.encodeToByteArray()) as? Received.Message)?.value
            },
            receivedAt = preferences[RECEIVED_AT],
            incompatibility = preferences[INCOMPATIBILITY]?.let { name ->
                Incompatibility.entries.firstOrNull { it.name == name }
            },
        )
    }

    /**
     * Keeps the state of the day in [message], received from the phone at
     * [receivedAt], or notes that the two apps do not understand each other.
     */
    suspend fun receiveState(message: ByteArray, receivedAt: Long) {
        when (val received = WatchMessages.decodeState(message)) {
            is Received.Message -> dataStore.edit {
                // Kept as written by the phone, read again by the protocol.
                it[STATE] = message.decodeToString()
                it[RECEIVED_AT] = receivedAt
                it.remove(INCOMPATIBILITY)
            }
            is Received.OtherVersion -> saveIncompatibility(
                if (received.version > WatchProtocol.VERSION) {
                    Incompatibility.UPDATE_WATCH
                } else {
                    Incompatibility.UPDATE_PHONE
                },
            )
            is Received.Unsupported -> saveIncompatibility(
                if (received.versions.any { it > WatchProtocol.VERSION }) {
                    Incompatibility.UPDATE_WATCH
                } else {
                    Incompatibility.UPDATE_PHONE
                },
            )
            // Not from the phone app: ignored.
            Received.Malformed -> Unit
        }
    }

    private suspend fun saveIncompatibility(incompatibility: Incompatibility) {
        dataStore.edit { it[INCOMPATIBILITY] = incompatibility.name }
    }

    private companion object {
        val STATE: Preferences.Key<String> = stringPreferencesKey("state")
        val RECEIVED_AT: Preferences.Key<Long> = longPreferencesKey("receivedAt")
        val INCOMPATIBILITY: Preferences.Key<String> = stringPreferencesKey("incompatibility")
    }
}
