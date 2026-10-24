package arbitro.android.protein_calculator

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.core.content.IntentCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.IOException
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {
    /** File shared to the app, kept until the app takes it. */
    private var sharedFile: Uri? = null
    private var sharedFileChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // Kept before the engine starts, so that the app finds it at launch.
        // An activity created again, or opened again from the recent apps,
        // gets the intent that first opened it: its file was taken then.
        if (intent.action == Intent.ACTION_SEND) {
            val again = savedInstanceState != null ||
                (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY) != 0
            if (!again) keepSharedFile(intent)
            intent = Intent()
        }
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        if (intent.action != Intent.ACTION_SEND) return super.onNewIntent(intent)
        keepSharedFile(intent)
        // Flutter and the plugins never read the share.
        super.onNewIntent(Intent())
        // The app is open: it takes the file at once.
        sharedFileChannel?.invokeMethod("available", null)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Opens the notification settings of the app, or its page in the
        // settings, where the user allows again what was refused.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "protein_calculator/settings")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openNotificationSettings" -> {
                        startActivity(notificationSettings())
                        result.success(null)
                    }
                    "openAppSettings" -> {
                        startActivity(appSettings())
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        // Gives the app the file shared to it, see lib/core/hevy/shared_file.dart.
        sharedFileChannel =
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "protein_calculator/shared_file")
                .apply {
                    setMethodCallHandler { call, result ->
                        when (call.method) {
                            "take" -> takeSharedFile(result)
                            else -> result.notImplemented()
                        }
                    }
                }
    }

    private fun appSettings(): Intent =
        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            .setData(Uri.fromParts("package", packageName, null))

    private fun notificationSettings(): Intent =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
        } else {
            // Android 7 has no page for the notifications alone.
            appSettings()
        }

    /** Keeps the file [intent] shares, if any, in place of the one kept. */
    private fun keepSharedFile(intent: Intent) {
        IntentCompat.getParcelableExtra(intent, Intent.EXTRA_STREAM, Uri::class.java)
            ?.let { sharedFile = it }
    }

    /**
     * Answers with the bytes of the file kept, or null if there is none, then
     * forgets it: the app imports it once. A file that cannot be read, or
     * larger than [MAX_SHARED_FILE_BYTES], answers an error.
     */
    private fun takeSharedFile(result: MethodChannel.Result) {
        val file = sharedFile ?: return result.success(null)
        sharedFile = null
        // Apart from the main thread: the app that shares it may be slow.
        thread {
            val bytes = try {
                read(file)
            } catch (_: Exception) {
                null
            }
            runOnUiThread {
                if (bytes != null) {
                    result.success(bytes)
                } else {
                    // The content and the name of the file stay on the phone.
                    result.error("unreadable", null, null)
                }
            }
        }
    }

    /** Reads [file], up to [MAX_SHARED_FILE_BYTES]. */
    private fun read(file: Uri): ByteArray {
        val input = contentResolver.openInputStream(file) ?: throw IOException("No content")
        return input.use { stream ->
            val bytes = ByteArrayOutputStream()
            val buffer = ByteArray(64 * 1024)
            var count = stream.read(buffer)
            while (count >= 0) {
                if (bytes.size() + count > MAX_SHARED_FILE_BYTES) throw IOException("Too large")
                bytes.write(buffer, 0, count)
                count = stream.read(buffer)
            }
            bytes.toByteArray()
        }
    }

    companion object {
        /** Largest file the app takes: an export of years of workouts is far smaller. */
        private const val MAX_SHARED_FILE_BYTES = 32 * 1024 * 1024
    }
}
