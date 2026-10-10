package arbitro.android.protein_calculator.wear

import arbitro.android.protein_calculator.protocol.WatchProtocol
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService
import kotlinx.coroutines.runBlocking

/**
 * Receives the state of the day the phone sends when it changes, even when
 * the watch app is closed: Google Play services start this service.
 */
class WatchListenerService : WearableListenerService() {
    override fun onMessageReceived(event: MessageEvent) {
        if (event.path != WatchProtocol.STATE_PATH) return
        // Called apart from the main thread: it may wait for the storage.
        val store = WatchStore(this)
        runBlocking { store.receiveState(event.data, System.currentTimeMillis()) }
    }
}
