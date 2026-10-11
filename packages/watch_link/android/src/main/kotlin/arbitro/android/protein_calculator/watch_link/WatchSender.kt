package arbitro.android.protein_calculator.watch_link

import android.content.Context
import arbitro.android.protein_calculator.protocol.DayState
import arbitro.android.protein_calculator.protocol.WatchMessages
import arbitro.android.protein_calculator.protocol.WatchProtocol
import com.google.android.gms.wearable.Node
import com.google.android.gms.wearable.Wearable

/**
 * Sends the state of the day to the watches having the app, only when they
 * are nearby (Bluetooth or local Wi-Fi): never through the servers of
 * Google, which carry the messages of distant devices.
 */
object WatchSender {
    /**
     * Sends [state] to the nearby devices among [nodes], or among all the
     * devices connected to the phone. Only the watch app receives it: a
     * device without it drops the message. Does nothing without a watch, or
     * on a phone without Wear OS.
     *
     * The devices are not looked up by capability: those only reach the
     * other device once Google Play services sync them, which may lag.
     */
    fun send(context: Context, state: DayState, nodes: Collection<Node>? = null) {
        val bytes = WatchMessages.encodeState(state)
        val messages = Wearable.getMessageClient(context)
        fun sendTo(watches: Collection<Node>) {
            for (watch in watches) {
                if (watch.isNearby) messages.sendMessage(watch.id, WatchProtocol.STATE_PATH, bytes)
            }
        }
        if (nodes != null) {
            sendTo(nodes)
            return
        }
        Wearable.getNodeClient(context).connectedNodes.addOnSuccessListener { sendTo(it) }
        // A failure means a phone without Wear OS: there is no watch to tell.
    }
}
