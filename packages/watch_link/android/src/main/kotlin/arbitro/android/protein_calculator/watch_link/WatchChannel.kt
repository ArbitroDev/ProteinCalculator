package arbitro.android.protein_calculator.watch_link

import android.content.Context
import arbitro.android.protein_calculator.protocol.DayState
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
    fun readState(callback: (DayState?) -> Unit) {
        channel.invokeMethod(
            "readState",
            null,
            object : MethodChannel.Result {
                override fun success(result: Any?) = callback(dayStateOf(result))

                override fun error(code: String, message: String?, details: Any?) = callback(null)

                override fun notImplemented() = callback(null)
            },
        )
    }

    companion object {
        const val NAME = "protein_calculator/watch"
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
            products = (map["products"] as List<*>).map { product ->
                product as Map<*, *>
                WatchProduct(
                    id = (product["id"] as Number).toLong(),
                    name = product["name"] as String,
                    protein = (product["protein"] as Number).toDouble(),
                    favorite = product["favorite"] as Boolean,
                )
            },
        )
    } catch (_: ClassCastException) {
        null
    } catch (_: NullPointerException) {
        null
    }
}
