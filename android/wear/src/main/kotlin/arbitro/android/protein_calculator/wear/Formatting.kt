package arbitro.android.protein_calculator.wear

import java.text.DecimalFormat
import java.text.DecimalFormatSymbols
import java.text.NumberFormat
import java.util.Locale
import kotlin.math.floor

/**
 * Whole grams shown for a total, a goal or what is left: truncated, as in
 * the phone app (`truncateGrams`), so the goal only shows as reached once it
 * really is. The epsilon absorbs floating point sums such as 59.99999 for 60.
 */
fun truncateGrams(grams: Double): Long = floor(grams + 1e-9).toLong()

/** [grams] truncated to the unit, formatted for [locale]: "1 234" in French. */
fun formatGrams(grams: Double, locale: Locale): String =
    NumberFormat.getIntegerInstance(locale).format(truncateGrams(grams))

/** Protein grams of one product, with one decimal at most: "10,5", "23". */
fun formatProtein(grams: Double, locale: Locale): String =
    DecimalFormat("#,##0.#", DecimalFormatSymbols.getInstance(locale)).format(grams)
