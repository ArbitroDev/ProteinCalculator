package arbitro.android.protein_calculator.wear

import arbitro.android.protein_calculator.protocol.WatchProtocol
import com.google.android.gms.wearable.CapabilityInfo
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService
import kotlinx.coroutines.runBlocking

/**
 * Receives the state of the day the phone sends when it changes, and learns
 * when the phone comes nearby, even when the watch app is closed: Google
 * Play services start this service. Either way, the phone can get the
 * additions and deletions waiting on the watch.
 */
class WatchListenerService : WearableListenerService() {
    override fun onMessageReceived(event: MessageEvent) {
        if (event.path != WatchProtocol.STATE_PATH) return
        // Called apart from the main thread: it may wait for the storage.
        val store = WatchStore(this)
        val waiting = runBlocking {
            store.receiveState(event.data, System.currentTimeMillis())
            store.hasWaiting()
        }
        if (waiting) SendWorker.schedule(this)
    }

    override fun onCapabilityChanged(info: CapabilityInfo) {
        if (info.nodes.any { it.isNearby }) SendWorker.schedule(this)
    }
}
