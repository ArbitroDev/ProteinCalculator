package arbitro.android.protein_calculator

import android.app.Activity
import android.content.ClipData
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.core.content.IntentCompat

/**
 * Receives the file shared to the app, from Hevy, and hands it to
 * [MainActivity] in the task of the app: the app comes back over the screen
 * it shows, or opens if it was closed, instead of starting again in a
 * second window over the app that shares. Shows nothing.
 */
class ShareActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Created again, the share was handed over already.
        if (savedInstanceState == null) {
            IntentCompat.getParcelableExtra(intent, Intent.EXTRA_STREAM, Uri::class.java)
                ?.let(::handOver)
        }
        finish()
    }

    private fun handOver(file: Uri) {
        val share = Intent(this, MainActivity::class.java)
            .setAction(Intent.ACTION_SEND)
            .setType(intent.type)
            .putExtra(Intent.EXTRA_STREAM, file)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION)
        // The right to read the file passes to MainActivity with the clip.
        share.clipData = ClipData.newRawUri(null, file)
        startActivity(share)
    }
}
