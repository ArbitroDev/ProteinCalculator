package arbitro.android.protein_calculator

import android.app.Activity
import android.content.Intent
import android.os.Bundle

/**
 * What the icons of the launcher open, through their aliases, see
 * [LauncherIcon]: it opens [AppActivity] in a task of its own, then closes.
 *
 * Android removes from the recent apps every task started from an alias it
 * turns off: opened from the launcher directly, the app would leave the
 * recent apps each time its icon changes. Opened from here, its task is
 * started from [AppActivity] itself, which never turns off.
 */
class LauncherActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // As the launcher does: an app already open comes back as it was.
        startActivity(
            Intent(this, AppActivity::class.java)
                .setAction(Intent.ACTION_MAIN)
                .addCategory(Intent.CATEGORY_LAUNCHER)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
        finish()
    }
}
