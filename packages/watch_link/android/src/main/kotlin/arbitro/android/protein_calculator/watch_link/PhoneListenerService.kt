package arbitro.android.protein_calculator.watch_link

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
 * start this service when a request arrives, or when a watch having the app
 * comes nearby. The data is read by [WatchEngine].
 */
class PhoneListenerService : WearableListenerService() {
    override fun onRequest(nodeId: String, path: String, request: ByteArray): Task<ByteArray>? {
        if (path != WatchProtocol.SYNC_PATH) return null
        return isNearby(nodeId).onSuccessTask { nearby ->
            when {
                // The answer would go through the servers of Google.
                !nearby -> Tasks.forException(IllegalStateException("Watch not nearby"))
                else -> when (WatchMessages.decodeSyncRequest(request)) {
                    is Received.Message ->
                        WatchEngine.readState(this).onSuccessTask { state ->
                            Tasks.forResult(WatchMessages.encodeState(state))
                        }
                    is Received.OtherVersion -> Tasks.forResult(WatchMessages.encodeUnsupported())
                    else -> Tasks.forException(IllegalArgumentException("Malformed request"))
                }
            }
        }
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
