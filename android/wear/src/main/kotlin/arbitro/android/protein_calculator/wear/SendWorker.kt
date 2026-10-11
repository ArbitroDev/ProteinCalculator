package arbitro.android.protein_calculator.wear

import android.content.Context
import androidx.work.BackoffPolicy
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import java.util.concurrent.TimeUnit

/**
 * Sends the additions and deletions waiting on the watch to the phone, even
 * once the watch app is closed. Run after each of them, when the phone shows
 * up, and every 15 minutes while some wait, in case the phone came nearby
 * unseen.
 */
class SendWorker(context: Context, parameters: WorkerParameters) : CoroutineWorker(context, parameters) {
    override suspend fun doWork(): Result {
        val store = WatchStore(applicationContext)
        return when (PhoneLink(applicationContext).sendPending(store)) {
            PhoneLink.Sending.DONE -> {
                WorkManager.getInstance(applicationContext).cancelUniqueWork(PERIODIC)
                Result.success()
            }
            // The next run comes when the phone shows up, or at the latest
            // with the periodic one.
            PhoneLink.Sending.PHONE_AWAY -> Result.success()
            // The phone is nearby but did not answer: again soon.
            PhoneLink.Sending.FAILED -> Result.retry()
        }
    }

    companion object {
        private const val NOW = "send"
        private const val PERIODIC = "send-periodic"

        /** Sends the waiting additions and deletions now, and every 15 minutes until they are all sent. */
        fun schedule(context: Context) {
            val work = WorkManager.getInstance(context)
            work.enqueueUniqueWork(
                NOW,
                // After a sending in progress, which may have missed the
                // newest addition.
                ExistingWorkPolicy.APPEND_OR_REPLACE,
                OneTimeWorkRequestBuilder<SendWorker>()
                    .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.SECONDS)
                    .build(),
            )
            work.enqueueUniquePeriodicWork(
                PERIODIC,
                ExistingPeriodicWorkPolicy.KEEP,
                PeriodicWorkRequestBuilder<SendWorker>(15, TimeUnit.MINUTES).build(),
            )
        }
    }
}
