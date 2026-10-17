package arbitro.android.protein_calculator.protocol

/**
 * Paths and capabilities of the messages exchanged between the phone app and
 * the watch app, through the MessageClient of the Wearable Data Layer, and
 * only between nearby devices. Described in PROTOCOL.md: any change of the
 * messages comes with a new [VERSION].
 */
object WatchProtocol {
    /** Version of the messages this app writes and reads. */
    const val VERSION = 2

    /**
     * Versions of the requests of the watch the phone reads: those of
     * version 1 hold no creatine, and their additions and deletions waiting
     * on a watch are never lost. The states and the answers of the phone are
     * only read in [VERSION].
     */
    val SUPPORTED_VERSIONS = listOf(1, VERSION)

    /** The phone sends the state of the day to the watch, see [DayState]. */
    const val STATE_PATH = "/protein_calculator/state"

    /**
     * Request of the watch, answered by the phone with the state of the day,
     * see [WatchMessages.encodeSyncRequest].
     */
    const val SYNC_PATH = "/protein_calculator/sync"

    /**
     * Additions of the watch, answered by the phone once made, see
     * [WatchMessages.encodeAddRequest] and [AddReply].
     */
    const val ADD_PATH = "/protein_calculator/add"

    /**
     * Deletions of entries of the day made on the watch, answered by the
     * phone once made, see [WatchMessages.encodeDeleteRequest] and
     * [DeleteReply].
     */
    const val DELETE_PATH = "/protein_calculator/delete"

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

    /** Most entries of the day sent to the watch: the most recent ones. */
    const val MAX_ENTRIES = 100

    /** Most products sent to the watch: the first ones of the list. */
    const val MAX_PRODUCTS = 100

    /** Most additions sent at once. */
    const val MAX_ADDITIONS = 50

    /** Most deletions sent at once. */
    const val MAX_DELETIONS = 50

    /** Longest id of an addition or a deletion. */
    const val MAX_ID_LENGTH = 64

    /** Most creatine doses of an entry or of one portion of a product. */
    const val MAX_CREATINE_DOSES = 9
}
