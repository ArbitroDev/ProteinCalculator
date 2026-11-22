package arbitro.android.protein_calculator

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager

/**
 * The icon of the app in the launcher: the usual one (alias `.MainActivity`,
 * the name the activity had, so that the icons already on home screens keep
 * working) or the Christmas one (alias `.ChristmasLauncher`), from December 1
 * to 25 while the Christmas theme is on.
 *
 * The app asks for the icon while it runs, see lib/core/launcher_icon.dart;
 * [AppActivity] applies it once the user leaves it. The Christmas icon also
 * sets an alarm at the end of the season, so that the usual icon comes back
 * on December 26 even if the app is not opened, see [LauncherIconReceiver].
 */
object LauncherIcon {
    /** Aliases of the activity in the manifest, one per launcher icon. */
    private const val USUAL_ALIAS = "MainActivity"
    private const val CHRISTMAS_ALIAS = "ChristmasLauncher"

    private const val PREFERENCES = "launcher_icon"

    /** When the Christmas season ends, in milliseconds since the epoch. */
    private const val SEASON_END = "seasonEnd"

    /**
     * Shows the Christmas icon in the launcher if [christmas], until
     * [seasonEnd] (milliseconds since the epoch), the usual one otherwise.
     * Android closes the tasks opened from an alias it turns off: call it
     * once the app is no longer seen.
     */
    fun set(context: Context, christmas: Boolean, seasonEnd: Long?) {
        setChristmasAlias(context, christmas)
        val preferences = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
        if (christmas && seasonEnd != null) {
            preferences.edit().putLong(SEASON_END, seasonEnd).apply()
            scheduleSeasonEnd(context, seasonEnd)
        } else {
            preferences.edit().remove(SEASON_END).apply()
            alarms(context).cancel(seasonEndIntent(context))
        }
    }

    /**
     * Puts the usual icon back once the season is over, or else waits for
     * its end again: at the alarm, and after a restart, which clears the
     * alarms.
     */
    internal fun checkSeasonEnd(context: Context) {
        val preferences = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
        val seasonEnd = preferences.getLong(SEASON_END, 0L).takeIf { it > 0 } ?: return
        if (System.currentTimeMillis() >= seasonEnd) {
            set(context, christmas = false, seasonEnd = null)
        } else {
            scheduleSeasonEnd(context, seasonEnd)
        }
    }

    /**
     * Shows the Christmas icon if [christmas], the usual one otherwise, by
     * turning on one alias and off the other. Does nothing when the right
     * one already shows: launchers may move the icon of a home screen when
     * it changes.
     */
    private fun setChristmasAlias(context: Context, christmas: Boolean) {
        val shown = if (christmas) CHRISTMAS_ALIAS else USUAL_ALIAS
        val hidden = if (christmas) USUAL_ALIAS else CHRISTMAS_ALIAS
        // The new icon first, so the app never leaves the launcher.
        setAliasEnabled(context, shown, true)
        setAliasEnabled(context, hidden, false)
    }

    private fun setAliasEnabled(context: Context, alias: String, enabled: Boolean) {
        val component = ComponentName(
            context.packageName,
            "${LauncherIcon::class.java.`package`!!.name}.$alias",
        )
        val packageManager = context.packageManager
        // Until changed once, an alias is as the manifest declares it.
        val isEnabled = when (packageManager.getComponentEnabledSetting(component)) {
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> true
            PackageManager.COMPONENT_ENABLED_STATE_DEFAULT -> alias == USUAL_ALIAS
            else -> false
        }
        if (isEnabled == enabled) return
        packageManager.setComponentEnabledSetting(
            component,
            if (enabled) {
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            } else {
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED
            },
            // The app goes on while its icon changes.
            PackageManager.DONT_KILL_APP,
        )
    }

    private fun scheduleSeasonEnd(context: Context, seasonEnd: Long) {
        // Within a few minutes after: exact alarms are kept for the reminders.
        alarms(context).setWindow(
            AlarmManager.RTC,
            seasonEnd,
            5 * 60 * 1000L,
            seasonEndIntent(context),
        )
    }

    private fun alarms(context: Context) = context.getSystemService(AlarmManager::class.java)

    private fun seasonEndIntent(context: Context): PendingIntent = PendingIntent.getBroadcast(
        context,
        0,
        Intent(context, LauncherIconReceiver::class.java)
            .setAction(LauncherIconReceiver.ACTION_SEASON_END),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )
}

/**
 * Puts the usual icon back at the end of the Christmas season, and waits for
 * it again after a restart, see [LauncherIcon.checkSeasonEnd].
 */
class LauncherIconReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_SEASON_END, Intent.ACTION_BOOT_COMPLETED -> LauncherIcon.checkSeasonEnd(context)
        }
    }

    companion object {
        const val ACTION_SEASON_END = "arbitro.android.protein_calculator.CHRISTMAS_SEASON_END"
    }
}
