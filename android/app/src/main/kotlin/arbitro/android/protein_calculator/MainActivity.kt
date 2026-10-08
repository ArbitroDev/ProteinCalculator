package arbitro.android.protein_calculator

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Opens the notification settings of the app, where the user turns
        // them on again after refusing them.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "protein_calculator/settings")
            .setMethodCallHandler { call, result ->
                if (call.method == "openNotificationSettings") {
                    startActivity(notificationSettings())
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun notificationSettings(): Intent =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
        } else {
            // Android 7 has no page for the notifications alone.
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                .setData(Uri.fromParts("package", packageName, null))
        }
}
