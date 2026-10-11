package arbitro.android.protein_calculator.protocol

import kotlinx.serialization.KSerializer
import kotlinx.serialization.SerialName
import kotlinx.serialization.SerializationException
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.int
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

/**
 * State of the current app day on the phone: what the watch shows.
 *
 * Values are exact: the watch truncates them as the phone app does.
 */
@Serializable
data class DayState(
    /** App day of [total], as `yyyymmdd`. */
    val day: Int,
    /** Hour the app days start, from 0 to 7, chosen in the phone app. */
    val dayStartHour: Int,
    /** Protein grams of the entries of [day]. */
    val total: Double,
    /** Goal of [day] in grams, null until the first launch of the phone app. */
    val goal: Double?,
    /** Entries of [day], the most recent first. */
    val entries: List<WatchEntry>,
    /** Saved products, the favorite first, in the order of the phone app. */
    val products: List<WatchProduct>,
    /**
     * Ids of the additions and deletions of the watch the phone made since
     * the start of the previous app day: those whose answer was lost are made
     * too.
     */
    val handled: List<String>,
) {
    internal fun isValid(): Boolean =
        isValidDay(day) &&
            dayStartHour in 0..MAX_DAY_START_HOUR &&
            total.isFinite() && total >= 0 &&
            (goal == null || (goal.isFinite() && goal > 0)) &&
            entries.size <= WatchProtocol.MAX_ENTRIES &&
            entries.all { it.isValid() } &&
            products.size <= WatchProtocol.MAX_PRODUCTS &&
            products.all { it.isValid() } &&
            products.count { it.favorite } <= 1 &&
            handled.all(::isValidAdditionId)

    companion object {
        const val MAX_DAY_START_HOUR = 7
    }
}

/** An entry of the day. */
@Serializable
data class WatchEntry(
    /** Id of the entry on the phone. */
    val id: Long,
    /** Its name, null for an entry without a name. */
    val name: String?,
    /** Protein grams. */
    val protein: Double,
    /** When it was added, in milliseconds since the epoch. */
    val time: Long,
    /** Whether it was added on the watch. */
    val fromWatch: Boolean,
) {
    internal fun isValid(): Boolean =
        id > 0 && (name == null || name.isNotBlank()) && protein.isFinite() && protein > 0 && time > 0
}

/** A saved product, which the watch adds one portion of. */
@Serializable
data class WatchProduct(
    /** Id of the product on the phone. */
    val id: Long,
    val name: String,
    /** Protein grams of one portion. */
    val protein: Double,
    val favorite: Boolean,
) {
    internal fun isValid(): Boolean =
        id > 0 && name.isNotBlank() && protein.isFinite() && protein > 0
}

/**
 * An entry added on the watch, for the phone to add: a portion of a
 * product, or a free entry of protein grams typed on the watch.
 */
@Serializable
data class WatchAddition(
    /** Random id given by the watch, the same each time it is sent. */
    val id: String,
    /** Id of the product on the phone, null for a free entry. */
    val productId: Long?,
    /**
     * Name and protein grams of one portion of the product, as the watch
     * showed them, or those typed for a free entry, whose name is optional.
     */
    val name: String?,
    val protein: Double,
    /** When it was added on the watch, in milliseconds since the epoch. */
    val addedAt: Long,
) {
    /** Whether the phone can add it: otherwise, the watch drops it. */
    fun isValid(): Boolean =
        isValidAdditionId(id) &&
            (productId == null || (productId > 0 && name != null)) &&
            (name == null || name.isNotBlank()) &&
            protein.isFinite() && protein > 0 && addedAt > 0
}

/** An entry of the day deleted on the watch, for the phone to delete. */
@Serializable
data class WatchDeletion(
    /** Random id given by the watch, the same each time it is sent. */
    val id: String,
    /** Id of the entry on the phone. */
    val entryId: Long,
    /**
     * When the entry was added, as the phone sent it: the phone deletes the
     * entry of that id only if it has that time.
     */
    val time: Long,
) {
    /** Whether the phone can delete it: otherwise, the watch drops it. */
    fun isValid(): Boolean = isValidAdditionId(id) && entryId > 0 && time > 0
}

/** Additions of the watch, oldest first, see [WatchProtocol.ADD_PATH]. */
@Serializable
data class AddRequest(val requests: List<WatchAddition>)

/** What the phone made of an addition. */
@Serializable
enum class AddStatus {
    /** Added to the day of its time. */
    @SerialName("added")
    ADDED,

    /** Already made from an earlier sending. */
    @SerialName("duplicate")
    DUPLICATE,

    /** Values the phone cannot add. */
    @SerialName("invalid")
    INVALID,
}

@Serializable
data class AddResult(val id: String, val status: AddStatus)

/** Answer of the phone to an [AddRequest]: each addition, then the new day. */
@Serializable
data class AddReply(val results: List<AddResult>, val state: DayState)

/** Deletions of the watch, oldest first, see [WatchProtocol.DELETE_PATH]. */
@Serializable
data class DeleteRequest(val requests: List<WatchDeletion>)

/** What the phone made of a deletion. */
@Serializable
enum class DeleteStatus {
    /** Deleted now. */
    @SerialName("deleted")
    DELETED,

    /** Already made from an earlier sending. */
    @SerialName("duplicate")
    DUPLICATE,

    /** No entry of that id and time: already deleted on the phone, or changed by a backup restored. */
    @SerialName("missing")
    MISSING,

    /** Values the phone cannot read. */
    @SerialName("invalid")
    INVALID,
}

@Serializable
data class DeleteResult(val id: String, val status: DeleteStatus)

/** Answer of the phone to a [DeleteRequest]: each deletion, then the new day. */
@Serializable
data class DeleteReply(val results: List<DeleteResult>, val state: DayState)

/** A message read by [WatchMessages]. */
sealed interface Received<out T> {
    /** A message of this version, with valid values. */
    data class Message<T>(val value: T) : Received<T>

    /** A message of [version], which this app does not read. */
    data class OtherVersion(val version: Int) : Received<Nothing>

    /**
     * The other app does not read the messages of this version: it reads
     * those of [versions].
     */
    data class Unsupported(val versions: List<Int>) : Received<Nothing>

    /** Not a message of this protocol, or values out of their range. */
    data object Malformed : Received<Nothing>
}

/**
 * Writes and reads the messages, as UTF-8 JSON objects whose `v` field holds
 * the version, see PROTOCOL.md. A message of another version is never read:
 * fields may have another meaning there.
 */
object WatchMessages {
    private const val VERSION_FIELD = "v"

    /** Answer to a message of a version this app does not read. Never changes. */
    private const val UNSUPPORTED_FIELD = "unsupported"

    private val json = Json { encodeDefaults = true }

    /** Writes [state], keeping its first entries and products, see [WatchProtocol]. */
    fun encodeState(state: DayState): ByteArray = encode(DayState.serializer(), state.limited())

    fun decodeState(bytes: ByteArray): Received<DayState> =
        decode(bytes, DayState.serializer()).validated { it.isValid() }

    /** Additions of the watch, [WatchProtocol.MAX_ADDITIONS] at most. */
    fun encodeAddRequest(additions: List<WatchAddition>): ByteArray =
        encode(AddRequest.serializer(), AddRequest(additions))

    /**
     * Reads the additions of the watch. The values of each are checked apart,
     * see [WatchAddition.isValid]: an invalid one does not stop the others.
     */
    fun decodeAddRequest(bytes: ByteArray): Received<AddRequest> =
        decode(bytes, AddRequest.serializer()).validated {
            it.requests.size in 1..WatchProtocol.MAX_ADDITIONS
        }

    /** Writes [reply], keeping the first entries and products of its state. */
    fun encodeAddReply(reply: AddReply): ByteArray =
        encode(AddReply.serializer(), reply.copy(state = reply.state.limited()))

    private fun DayState.limited() = copy(
        entries = entries.take(WatchProtocol.MAX_ENTRIES),
        products = products.take(WatchProtocol.MAX_PRODUCTS),
    )

    fun decodeAddReply(bytes: ByteArray): Received<AddReply> =
        decode(bytes, AddReply.serializer()).validated { reply ->
            reply.state.isValid() && reply.results.all { isValidAdditionId(it.id) }
        }

    /** Deletions of the watch, [WatchProtocol.MAX_DELETIONS] at most. */
    fun encodeDeleteRequest(deletions: List<WatchDeletion>): ByteArray =
        encode(DeleteRequest.serializer(), DeleteRequest(deletions))

    /**
     * Reads the deletions of the watch. The values of each are checked apart,
     * see [WatchDeletion.isValid]: an invalid one does not stop the others.
     */
    fun decodeDeleteRequest(bytes: ByteArray): Received<DeleteRequest> =
        decode(bytes, DeleteRequest.serializer()).validated {
            it.requests.size in 1..WatchProtocol.MAX_DELETIONS
        }

    /** Writes [reply], keeping the first entries and products of its state. */
    fun encodeDeleteReply(reply: DeleteReply): ByteArray =
        encode(DeleteReply.serializer(), reply.copy(state = reply.state.limited()))

    fun decodeDeleteReply(bytes: ByteArray): Received<DeleteReply> =
        decode(bytes, DeleteReply.serializer()).validated { reply ->
            reply.state.isValid() && reply.results.all { isValidAdditionId(it.id) }
        }

    /** Request of the watch for the state of the day. */
    fun encodeSyncRequest(): ByteArray = encode(SyncRequest.serializer(), SyncRequest)

    fun decodeSyncRequest(bytes: ByteArray): Received<Unit> =
        when (val received = decode(bytes, SyncRequest.serializer())) {
            is Received.Message -> Received.Message(Unit)
            is Received.OtherVersion -> received
            is Received.Unsupported -> received
            Received.Malformed -> Received.Malformed
        }

    /** Answer to a message of a version this app does not read. */
    fun encodeUnsupported(): ByteArray {
        val versions = JsonArray(WatchProtocol.SUPPORTED_VERSIONS.map { JsonPrimitive(it) })
        return JsonObject(mapOf(UNSUPPORTED_FIELD to versions)).toString().encodeToByteArray()
    }

    private fun <T> encode(serializer: KSerializer<T>, message: T): ByteArray {
        val fields = json.encodeToJsonElement(serializer, message).jsonObject
        val version = mapOf(VERSION_FIELD to JsonPrimitive(WatchProtocol.VERSION))
        return JsonObject(version + fields).toString().encodeToByteArray()
    }

    private fun <T> decode(bytes: ByteArray, serializer: KSerializer<T>): Received<T> =
        try {
            val message = json.parseToJsonElement(bytes.decodeToString()).jsonObject
            val unsupported = message[UNSUPPORTED_FIELD]
            val version = message[VERSION_FIELD]?.jsonPrimitive?.intOrNull
            when {
                unsupported != null ->
                    Received.Unsupported((unsupported as JsonArray).map { it.jsonPrimitive.int })
                version == null -> Received.Malformed
                version !in WatchProtocol.SUPPORTED_VERSIONS -> Received.OtherVersion(version)
                else -> Received.Message(
                    json.decodeFromJsonElement(serializer, JsonObject(message - VERSION_FIELD)),
                )
            }
        } catch (_: SerializationException) {
            Received.Malformed
        } catch (_: IllegalArgumentException) {
            // Not an object, or a field of another type.
            Received.Malformed
        } catch (_: ClassCastException) {
            Received.Malformed
        }

    private fun <T> Received<T>.validated(isValid: (T) -> Boolean): Received<T> =
        if (this is Received.Message && !isValid(value)) Received.Malformed else this
}

/** Fields of the request for the state: none besides the version. */
@Serializable
private data object SyncRequest

/** Whether [id] can be the id of a [WatchAddition] or a [WatchDeletion]. */
private fun isValidAdditionId(id: String): Boolean = id.length in 1..WatchProtocol.MAX_ID_LENGTH

/** Whether [day] is a `yyyymmdd` date of a real day: 20260931 is not. */
private fun isValidDay(day: Int): Boolean {
    val year = day / 10000
    val month = day / 100 % 100
    val dayOfMonth = day % 100
    if (year !in 1..9999 || month !in 1..12) return false
    val leap = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
    val length = when (month) {
        2 -> if (leap) 29 else 28
        4, 6, 9, 11 -> 30
        else -> 31
    }
    return dayOfMonth in 1..length
}
