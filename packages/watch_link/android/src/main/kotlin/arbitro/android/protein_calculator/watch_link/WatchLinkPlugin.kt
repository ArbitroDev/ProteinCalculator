package arbitro.android.protein_calculator.watch_link

import io.flutter.embedding.engine.plugins.FlutterPlugin

/**
 * Link with the watch app, registered in every Flutter engine of the app:
 * the app itself, the buttons of the notifications and [WatchEngine] can all
 * send the state of the day to the watch.
 */
class WatchLinkPlugin : FlutterPlugin {
    /** Channel of the engine this plugin is attached to. */
    internal var channel: WatchChannel? = null
        private set

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = WatchChannel(binding.applicationContext, binding.binaryMessenger)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.dispose()
        channel = null
    }
}
