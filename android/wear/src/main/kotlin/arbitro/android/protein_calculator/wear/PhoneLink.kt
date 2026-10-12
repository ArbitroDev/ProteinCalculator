package arbitro.android.protein_calculator.wear

import android.content.Context
import arbitro.android.protein_calculator.protocol.WatchMessages
import arbitro.android.protein_calculator.protocol.WatchProtocol
import com.google.android.gms.common.api.ApiException
import com.google.android.gms.wearable.CapabilityClient
import com.google.android.gms.wearable.CapabilityInfo
import com.google.android.gms.wearable.Node
import com.google.android.gms.wearable.Wearable
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.merge
import kotlinx.coroutines.tasks.await

/**
 * Link with the phone having the app, only when it is nearby (Bluetooth or
 * local Wi-Fi): never through the servers of Google, which carry the
 * messages of distant devices.
 */
class PhoneLink(context: Context) {
    private val context = context.applicationContext
    private val capabilities = Wearable.getCapabilityClient(this.context)
    private val messages = Wearable.getMessageClient(this.context)

    /**
     * The phone, if it is nearby. A watch is connected to one phone. It is
     * not looked up by capability: those only reach the watch once Google
     * Play services sync them, which may lag.
     */
    suspend fun nearbyPhone(): Node? =
        try {
            Wearable.getNodeClient(context).connectedNodes.await().firstOrNull { it.isNearby }
        } catch (_: ApiException) {
            null
        }

    /**
     * Whether the phone is nearby, checked again at each [ticks] value and
     * when the phone app is seen coming or going.
     */
    fun phoneNearby(ticks: Flow<*>): Flow<Boolean> = merge(
        ticks.map { nearbyPhone() != null },
        callbackFlow {
            val listener = CapabilityClient.OnCapabilityChangedListener { info: CapabilityInfo ->
                trySend(info.nodes.any { it.isNearby })
            }
            capabilities.addListener(listener, WatchProtocol.PHONE_CAPABILITY)
            awaitClose { capabilities.removeListener(listener) }
        },
    ).distinctUntilChanged()

    /**
     * Asks the nearby phone for the state of the day and keeps it in [store].
     * Returns false if no phone answered: the watch keeps its state.
     */
    suspend fun sync(store: WatchStore): Boolean {
        val phone = nearbyPhone() ?: return false
        val reply = try {
            messages.sendRequest(phone.id, WatchProtocol.SYNC_PATH, WatchMessages.encodeSyncRequest())
                .await()
        } catch (_: ApiException) {
            return false
        }
        store.receiveState(reply, System.currentTimeMillis())
        return true
    }

    /** What became of the additions and deletions waiting for the phone. */
    enum class Sending {
        /** The phone made them all. */
        DONE,

        /** No phone nearby: they wait for it. */
        PHONE_AWAY,

        /** The phone did not answer, or not in a way the watch understands. */
        FAILED,
    }

    /**
     * Sends the additions, then the deletions, waiting in [store] to the
     * nearby phone, oldest first, by batches. Each stays until the phone
     * answers for it: one sent again is not made twice by the phone.
     */
    suspend fun sendPending(store: WatchStore): Sending {
        val additions = send(
            waiting = { store.pending().map { it.id to it } },
            most = WatchProtocol.MAX_ADDITIONS,
            path = WatchProtocol.ADD_PATH,
            encode = WatchMessages::encodeAddRequest,
            receive = store::receiveAddReply,
        )
        if (additions != Sending.DONE) return additions
        return send(
            waiting = { store.deletions().map { it.id to it } },
            most = WatchProtocol.MAX_DELETIONS,
            path = WatchProtocol.DELETE_PATH,
            encode = WatchMessages::encodeDeleteRequest,
            receive = store::receiveDeleteReply,
        )
    }

    /**
     * Sends the requests [waiting] returns, by id, [most] at once on [path],
     * until none waits: [receive] keeps each answer and says whether the
     * phone answered.
     */
    private suspend fun <T> send(
        waiting: suspend () -> List<Pair<String, T>>,
        most: Int,
        path: String,
        encode: (List<T>) -> ByteArray,
        receive: suspend (ByteArray, Long) -> Boolean,
    ): Sending {
        while (true) {
            val requests = waiting()
            if (requests.isEmpty()) return Sending.DONE
            val phone = nearbyPhone() ?: return Sending.PHONE_AWAY
            val batch = requests.take(most)
            val reply = try {
                messages.sendRequest(phone.id, path, encode(batch.map { it.second })).await()
            } catch (_: ApiException) {
                return Sending.FAILED
            }
            if (!receive(reply, System.currentTimeMillis())) return Sending.FAILED
            // An answer leaving the oldest request waiting would loop forever.
            if (waiting().any { it.first == batch.first().first }) return Sending.FAILED
        }
    }
}
