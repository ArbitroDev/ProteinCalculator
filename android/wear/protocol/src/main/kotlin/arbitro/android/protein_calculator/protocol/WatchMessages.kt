package arbitro.android.protein_calculator.protocol

import kotlinx.serialization.KSerializer
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
 * Values are exact: the watch rounds them as the phone app does.
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
    /** Saved products, the favorite first, in the order of the phone app. */
    val products: List<WatchProduct>,
) {
    internal fun isValid(): Boolean =
        isValidDay(day) &&
            dayStartHour in 0..MAX_DAY_START_HOUR &&
            total.isFinite() && total >= 0 &&
            (goal == null || (goal.isFinite() && goal > 0)) &&
            products.size <= WatchProtocol.MAX_PRODUCTS &&
            products.all { it.isValid() } &&
            products.count { it.favorite } <= 1

    companion object {
        const val MAX_DAY_START_HOUR = 7
    }
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

    /** Writes [state], keeping its first [WatchProtocol.MAX_PRODUCTS] products. */
    fun encodeState(state: DayState): ByteArray =
        encode(
            DayState.serializer(),
            state.copy(products = state.products.take(WatchProtocol.MAX_PRODUCTS)),
        )

    fun decodeState(bytes: ByteArray): Received<DayState> =
        decode(bytes, DayState.serializer()).validated { it.isValid() }

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
