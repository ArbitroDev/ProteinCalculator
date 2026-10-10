package arbitro.android.protein_calculator.protocol

/**
 * Paths and capabilities of the messages exchanged between the phone app and
 * the watch app, through the MessageClient of the Wearable Data Layer, and
 * only between nearby devices. Described in PROTOCOL.md: any change of the
 * messages comes with a new [VERSION].
 */
object WatchProtocol {
    /** Version of the messages this app writes and reads. */
    const val VERSION = 1

    /** Versions of the messages this app reads. */
    val SUPPORTED_VERSIONS = listOf(VERSION)

    /** The phone sends the state of the day to the watch, see [DayState]. */
    const val STATE_PATH = "/protein_calculator/state"

    /**
     * Request of the watch, answered by the phone with the state of the day,
     * see [WatchMessages.encodeSyncRequest].
     */
    const val SYNC_PATH = "/protein_calculator/sync"

    /**
     * Capability of the phones having the app, declared in its resources:
     * tells the watch the phone app comes nearby.
     */
    const val PHONE_CAPABILITY = "protein_calculator_phone"

    /**
     * Capability of the watches having the app, reading the messages of
     * [version], declared in its resources: tells the phone the watch app
     * comes nearby.
     */
    fun watchCapability(version: Int = VERSION) = "protein_calculator_watch_v$version"

    /** Most products sent to the watch: the first ones of the list. */
    const val MAX_PRODUCTS = 100
}
