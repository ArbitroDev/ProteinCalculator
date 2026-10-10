package arbitro.android.protein_calculator.watch_link

import android.annotation.SuppressLint
import android.content.Context
import android.os.Handler
import android.os.Looper
import arbitro.android.protein_calculator.protocol.DayState
import com.google.android.gms.tasks.Task
import com.google.android.gms.tasks.TaskCompletionSource
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import java.util.concurrent.Executor
import java.util.concurrent.TimeoutException

/**
 * Flutter engine started apart from the app to answer the watch, even when
 * the app is closed. Its Dart code, `watchBackgroundMain` in
 * lib/core/watch/watch_sync.dart of the app, opens the data as the app does:
 * the rules of the app (day, goal, products) are written once, in Dart.
 *
 * Started on the first request, it stays for a minute after the last one, so
 * that a series of requests starts it once. Only used on the main thread.
 */
object WatchEngine {
    private const val ENTRYPOINT_LIBRARY = "package:protein_calculator/core/watch/watch_sync.dart"
    private const val ENTRYPOINT = "watchBackgroundMain"

    /** Longest wait for an answer of the Dart code, starting the engine included. */
    private const val TIMEOUT_MS = 20_000L

    /** How long the engine stays after the last request. */
    private const val IDLE_MS = 60_000L

    private val handler = Handler(Looper.getMainLooper())
    private val mainThread = Executor { handler.post(it) }
    private val stop = Runnable { destroy() }

    private var engine: FlutterEngine? = null
    // Holds the application context only, which lives as long as the app.
    @SuppressLint("StaticFieldLeak")
    private var channel: WatchChannel? = null
    private var ready = false

    /** Requests waiting for the Dart code to start. */
    private val waiting = ArrayDeque<(WatchChannel) -> Unit>()

    /** Requests not answered yet. */
    private var running = 0

    /** Reads the state of the current app day from the data. */
    fun readState(context: Context): Task<DayState> {
        val source = TaskCompletionSource<DayState>()
        handler.post {
            start()
            val timeout = Runnable {
                if (source.trySetException(TimeoutException("No answer of the Dart code"))) {
                    // An engine that never got ready is started again next time.
                    if (!ready) destroy()
                }
            }
            handler.postDelayed(timeout, TIMEOUT_MS)
            withChannel(context) { channel ->
                channel.readState { state ->
                    handler.removeCallbacks(timeout)
                    if (state != null) {
                        source.trySetResult(state)
                    } else {
                        source.trySetException(IllegalStateException("No state of the day"))
                    }
                }
            }
        }
        source.task.addOnCompleteListener(mainThread) { finish() }
        return source.task
    }

    private fun start() {
        running++
        handler.removeCallbacks(stop)
    }

    private fun finish() {
        running--
        if (running == 0) handler.postDelayed(stop, IDLE_MS)
    }

    /** Runs [action] once the Dart code answers, starting the engine if needed. */
    private fun withChannel(context: Context, action: (WatchChannel) -> Unit) {
        val current = channel
        if (current != null && ready) {
            action(current)
            return
        }
        waiting.addLast(action)
        if (engine != null) return
        try {
            launch(context.applicationContext)
        } catch (_: RuntimeException) {
            // The request fails at its timeout; the next one tries again.
            destroy()
        }
    }

    private fun launch(context: Context) {
        // The plugins of the app, this one included, register on their own.
        val engine = FlutterEngine(context)
        val plugin = engine.plugins.get(WatchLinkPlugin::class.java) as WatchLinkPlugin
        val channel = checkNotNull(plugin.channel)
        channel.onReady = {
            ready = true
            while (waiting.isNotEmpty()) waiting.removeFirst()(channel)
        }
        this.engine = engine
        this.channel = channel
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint(
                FlutterInjector.instance().flutterLoader().findAppBundlePath(),
                ENTRYPOINT_LIBRARY,
                ENTRYPOINT,
            ),
        )
    }

    private fun destroy() {
        engine?.destroy()
        engine = null
        channel = null
        ready = false
        // Their timeouts fail them.
        waiting.clear()
    }
}
