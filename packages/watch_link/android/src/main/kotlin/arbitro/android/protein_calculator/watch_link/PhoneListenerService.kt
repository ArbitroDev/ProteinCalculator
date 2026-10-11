package arbitro.android.protein_calculator.watch_link

import arbitro.android.protein_calculator.protocol.AddReply
import arbitro.android.protein_calculator.protocol.AddResult
import arbitro.android.protein_calculator.protocol.AddStatus
import arbitro.android.protein_calculator.protocol.DeleteReply
import arbitro.android.protein_calculator.protocol.DeleteResult
import arbitro.android.protein_calculator.protocol.DeleteStatus
import arbitro.android.protein_calculator.protocol.Received
import arbitro.android.protein_calculator.protocol.WatchMessages
import arbitro.android.protein_calculator.protocol.WatchProtocol
import com.google.android.gms.tasks.Task
import com.google.android.gms.tasks.Tasks
import com.google.android.gms.wearable.CapabilityInfo
import com.google.android.gms.wearable.Wearable
import com.google.android.gms.wearable.WearableListenerService

/**
 * Answers the watch app, even when the app is closed: Google Play services
 * start this service when a request arrives (the state of the day,
 * additions or deletions), or when a watch having the app comes nearby. The data is read
 * and written by [WatchEngine].
 */
class PhoneListenerService : WearableListenerService() {
    override fun onRequest(nodeId: String, path: String, request: ByteArray): Task<ByteArray>? {
        val answer: () -> Task<ByteArray> = when (path) {
            WatchProtocol.SYNC_PATH -> { { sync(request) } }
            WatchProtocol.ADD_PATH -> { { add(request) } }
            WatchProtocol.DELETE_PATH -> { { delete(request) } }
            else -> return null
        }
        return isNearby(nodeId).onSuccessTask { nearby ->
            // The answer would go through the servers of Google.
            if (nearby) answer() else Tasks.forException(IllegalStateException("Watch not nearby"))
        }
    }

    private fun sync(request: ByteArray): Task<ByteArray> =
        when (WatchMessages.decodeSyncRequest(request)) {
            is Received.Message ->
                WatchEngine.readState(this).onSuccessTask { state ->
                    Tasks.forResult(WatchMessages.encodeState(state))
                }
            is Received.OtherVersion -> Tasks.forResult(WatchMessages.encodeUnsupported())
            else -> Tasks.forException(IllegalArgumentException("Malformed request"))
        }

    /** Makes the valid additions, and tells the watch to drop the others. */
    private fun add(request: ByteArray): Task<ByteArray> =
        when (val received = WatchMessages.decodeAddRequest(request)) {
            is Received.Message -> {
                val (valid, invalid) = received.value.requests.partition { it.isValid() }
                val invalidResults = invalid.map { AddResult(it.id, AddStatus.INVALID) }
                if (valid.isEmpty()) {
                    WatchEngine.readState(this).onSuccessTask { state ->
                        Tasks.forResult(WatchMessages.encodeAddReply(AddReply(invalidResults, state)))
                    }
                } else {
                    WatchEngine.addPortions(this, valid).onSuccessTask { reply ->
                        val results = reply.results + invalidResults
                        Tasks.forResult(WatchMessages.encodeAddReply(reply.copy(results = results)))
                    }
                }
            }
            is Received.OtherVersion -> Tasks.forResult(WatchMessages.encodeUnsupported())
            else -> Tasks.forException(IllegalArgumentException("Malformed request"))
        }

    /** Makes the valid deletions, and tells the watch to drop the others. */
    private fun delete(request: ByteArray): Task<ByteArray> =
        when (val received = WatchMessages.decodeDeleteRequest(request)) {
            is Received.Message -> {
                val (valid, invalid) = received.value.requests.partition { it.isValid() }
                val invalidResults = invalid.map { DeleteResult(it.id, DeleteStatus.INVALID) }
                if (valid.isEmpty()) {
                    WatchEngine.readState(this).onSuccessTask { state ->
                        Tasks.forResult(WatchMessages.encodeDeleteReply(DeleteReply(invalidResults, state)))
                    }
                } else {
                    WatchEngine.deleteEntries(this, valid).onSuccessTask { reply ->
                        val results = reply.results + invalidResults
                        Tasks.forResult(WatchMessages.encodeDeleteReply(reply.copy(results = results)))
                    }
                }
            }
            is Received.OtherVersion -> Tasks.forResult(WatchMessages.encodeUnsupported())
            else -> Tasks.forException(IllegalArgumentException("Malformed request"))
        }

    override fun onCapabilityChanged(info: CapabilityInfo) {
        // A watch having the app came nearby, or got the app: it gets the
        // state of the day.
        val watches = info.nodes.filter { it.isNearby }
        if (info.name != WatchProtocol.watchCapability() || watches.isEmpty()) return
        WatchEngine.readState(this).addOnSuccessListener { state ->
            WatchSender.send(this, state, watches)
        }
    }

    /** Whether the device [nodeId] is connected directly to the phone. */
    private fun isNearby(nodeId: String): Task<Boolean> =
        Wearable.getNodeClient(this).connectedNodes.onSuccessTask { nodes ->
            Tasks.forResult(nodes.any { it.id == nodeId && it.isNearby })
        }
}
