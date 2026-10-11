package arbitro.android.protein_calculator.wear

import android.content.Context
import androidx.datastore.preferences.core.MutablePreferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.preferencesDataStore
import arbitro.android.protein_calculator.protocol.DayState
import arbitro.android.protein_calculator.protocol.Received
import arbitro.android.protein_calculator.protocol.WatchAddition
import arbitro.android.protein_calculator.protocol.WatchDeletion
import arbitro.android.protein_calculator.protocol.WatchMessages
import arbitro.android.protein_calculator.protocol.WatchProduct
import java.util.UUID
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
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
    /** Additions made on the watch the phone has not made yet, oldest first. */
    val pending: List<WatchAddition>,
    /** Entries deleted on the watch the phone has not deleted yet, oldest first. */
    val deletions: List<WatchDeletion>,
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
        ProteinComplicationService.refresh(context)
    }

    val saved: Flow<Saved> = dataStore.data.map { it.toSaved() }

    /** Additions waiting for the phone, oldest first. */
    suspend fun pending(): List<WatchAddition> = saved.first().pending

    /** Deletions waiting for the phone, oldest first. */
    suspend fun deletions(): List<WatchDeletion> = saved.first().deletions

    /** Whether additions or deletions wait for the phone. */
    suspend fun hasWaiting(): Boolean = saved.first().let { it.pending.isNotEmpty() || it.deletions.isNotEmpty() }

    /** Adds a portion of [product] at [now], in milliseconds since the epoch, for the phone to add. */
    suspend fun add(product: WatchProduct, now: Long): WatchAddition {
        val addition = WatchAddition(
            id = UUID.randomUUID().toString(),
            productId = product.id,
            name = product.name,
            protein = product.protein,
            addedAt = now,
        )
        edit { it.addPending(addition) }
        return addition
    }

    /**
     * Deletes [entry]: an addition waiting for the phone is dropped, the
     * deletion of an entry the phone made is kept for the phone to make,
     * now or once it is nearby. Returns whether the phone has to be told.
     */
    suspend fun delete(entry: DayEntry): Boolean {
        val additionId = entry.additionId
        if (additionId != null) {
            edit { it.removePending(additionId) }
            return false
        }
        val entryId = entry.entryId ?: return false
        val deletion = WatchDeletion(id = UUID.randomUUID().toString(), entryId = entryId, time = entry.time)
        edit { it.addDeletion(deletion) }
        return true
    }

    /**
     * Keeps the state of the day in [message], received from the phone at
     * [receivedAt], or notes that the two apps do not understand each other.
     */
    suspend fun receiveState(message: ByteArray, receivedAt: Long) {
        when (val received = WatchMessages.decodeState(message)) {
            is Received.Message -> edit { it.keepState(received.value, receivedAt) }
            is Received.OtherVersion -> edit { it.noteIncompatibility(received.version) }
            is Received.Unsupported -> edit { it.noteIncompatibility(received.versions.max()) }
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
                edit { it.keepReply(received.value, receivedAt) }
                true
            }
            is Received.OtherVersion -> {
                edit { it.noteIncompatibility(received.version) }
                false
            }
            is Received.Unsupported -> {
                edit { it.noteIncompatibility(received.versions.max()) }
                false
            }
            Received.Malformed -> false
        }

    /**
     * Drops the deletions the phone answered for in [message], received at
     * [receivedAt], and keeps the new state of the day. Returns whether the
     * phone answered.
     */
    suspend fun receiveDeleteReply(message: ByteArray, receivedAt: Long): Boolean =
        when (val received = WatchMessages.decodeDeleteReply(message)) {
            is Received.Message -> {
                edit { it.keepReply(received.value, receivedAt) }
                true
            }
            is Received.OtherVersion -> {
                edit { it.noteIncompatibility(received.version) }
                false
            }
            is Received.Unsupported -> {
                edit { it.noteIncompatibility(received.versions.max()) }
                false
            }
            Received.Malformed -> false
        }
}
