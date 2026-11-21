package arbitro.android.protein_calculator

import android.content.ContentResolver
import android.content.Context
import android.net.Uri

/**
 * Whether [file] can be a file shared to the app by another app: a content
 * of another app's provider. Never a path (`file://`), which the app would
 * read with its own rights, nor a content of the app itself, such as its
 * shared images: the app only ever reads what another app hands it.
 */
internal fun Context.isSharedByAnotherApp(file: Uri): Boolean {
    if (file.scheme != ContentResolver.SCHEME_CONTENT) return false
    val authority = file.authority ?: return false
    // An authority may list several, separated by semicolons.
    return authority.split(';').none { it == packageName || it.startsWith("$packageName.") }
}
