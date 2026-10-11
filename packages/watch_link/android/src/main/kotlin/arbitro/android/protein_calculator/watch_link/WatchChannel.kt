package arbitro.android.protein_calculator.watch_link

import android.content.Context
import arbitro.android.protein_calculator.protocol.AddReply
import arbitro.android.protein_calculator.protocol.AddResult
import arbitro.android.protein_calculator.protocol.AddStatus
import arbitro.android.protein_calculator.protocol.DayState
import arbitro.android.protein_calculator.protocol.DeleteReply
import arbitro.android.protein_calculator.protocol.DeleteResult
import arbitro.android.protein_calculator.protocol.DeleteStatus
import arbitro.android.protein_calculator.protocol.WatchAddition
import arbitro.android.protein_calculator.protocol.WatchDeletion
import arbitro.android.protein_calculator.protocol.WatchEntry
import arbitro.android.protein_calculator.protocol.WatchProduct
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Channel between the Dart code and the link with the watch app, see
 * lib/watch_link.dart of this plugin.
 *
 * The Dart code sends the state of the day each time it changes. In the
 * engine started for the watch, [WatchEngine], it also reads it when the
 * watch asks.
 */
class WatchChannel(context: Context, messenger: BinaryMessenger) {
    private val context = context.applicationContext
    private val channel = MethodChannel(messenger, NAME)

    /** Called once the Dart code of [WatchEngine] answers the requests. */
    var onReady: (() -> Unit)? = null

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "sendState" -> {
                    val state = dayStateOf(call.arguments)
                    if (state == null) {
                        result.error("invalid", "Invalid state of the day", null)
                    } else {
                        WatchSender.send(context, state)
                        result.success(null)
                    }
                }
                "ready" -> {
                    onReady?.invoke()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    fun dispose() = channel.setMethodCallHandler(null)

    /** Asks the Dart code for the state of the day, null if it fails. */
    fun readState(callback: (DayState?) -> Unit) = call("readState", null) { callback(dayStateOf(it)) }

    /**
     * Asks the Dart code to make [additions], all valid: [callback] gets the
     * results and the new state of the day, or null if it fails.
     */
    fun addPortions(additions: List<WatchAddition>, callback: (AddReply?) -> Unit) {
        val arguments = additions.map {
            mapOf(
                "id" to it.id,
                "productId" to it.productId,
                "name" to it.name,
                "protein" to it.protein,
                "addedAt" to it.addedAt,
            )
        }
        call("addPortions", arguments) { callback(addReplyOf(it)) }
    }

    /**
     * Asks the Dart code to make [deletions], all valid: [callback] gets the
     * results and the new state of the day, or null if it fails.
     */
    fun deleteEntries(deletions: List<WatchDeletion>, callback: (DeleteReply?) -> Unit) {
        val arguments = deletions.map {
            mapOf("id" to it.id, "entryId" to it.entryId, "time" to it.time)
        }
        call("deleteEntries", arguments) { callback(deleteReplyOf(it)) }
    }

    private fun call(method: String, arguments: Any?, callback: (Any?) -> Unit) {
        channel.invokeMethod(
            method,
            arguments,
            object : MethodChannel.Result {
                override fun success(result: Any?) = callback(result)

                override fun error(code: String, message: String?, details: Any?) = callback(null)

                override fun notImplemented() = callback(null)
            },
        )
    }

    companion object {
        const val NAME = "protein_calculator/watch"
    }
}

/** Results of the additions and new state sent by the Dart code as a map. */
private fun addReplyOf(arguments: Any?): AddReply? = replyOf(arguments) { results, state ->
    AddReply(
        results = results.map { (id, status) ->
            AddResult(id, AddStatus.entries.first { it.name.equals(status, ignoreCase = true) })
        },
        state = state,
    )
}

/** Results of the deletions and new state sent by the Dart code as a map. */
private fun deleteReplyOf(arguments: Any?): DeleteReply? = replyOf(arguments) { results, state ->
    DeleteReply(
        results = results.map { (id, status) ->
            DeleteResult(id, DeleteStatus.entries.first { it.name.equals(status, ignoreCase = true) })
        },
        state = state,
    )
}

/**
 * Reply sent by the Dart code as a map of `results` (`id` and `status` of
 * each request) and `state`, made by [reply].
 */
private fun <T> replyOf(arguments: Any?, reply: (List<Pair<String, String>>, DayState) -> T): T? {
    val map = arguments as? Map<*, *> ?: return null
    val state = dayStateOf(map["state"]) ?: return null
    return try {
        val results = (map["results"] as List<*>).map { result ->
            result as Map<*, *>
            result["id"] as String to result["status"] as String
        }
        reply(results, state)
    } catch (_: RuntimeException) {
        // A value missing or of another type.
        null
    }
}

/** State of the day sent by the Dart code as a map, see `WatchState.toChannel` in the app. */
private fun dayStateOf(arguments: Any?): DayState? {
    val map = arguments as? Map<*, *> ?: return null
    return try {
        DayState(
            day = (map["day"] as Number).toInt(),
            dayStartHour = (map["dayStartHour"] as Number).toInt(),
            total = (map["total"] as Number).toDouble(),
            goal = (map["goal"] as Number?)?.toDouble(),
            entries = (map["entries"] as List<*>).map { entry ->
                entry as Map<*, *>
                WatchEntry(
                    id = (entry["id"] as Number).toLong(),
                    name = entry["name"] as String?,
                    protein = (entry["protein"] as Number).toDouble(),
                    time = (entry["time"] as Number).toLong(),
                    fromWatch = entry["fromWatch"] as Boolean,
                )
            },
            products = (map["products"] as List<*>).map { product ->
                product as Map<*, *>
                WatchProduct(
                    id = (product["id"] as Number).toLong(),
                    name = product["name"] as String,
                    protein = (product["protein"] as Number).toDouble(),
                    favorite = product["favorite"] as Boolean,
                )
            },
            handled = (map["handled"] as List<*>).map { it as String },
        )
    } catch (_: ClassCastException) {
        null
    } catch (_: NullPointerException) {
        null
    }
}
