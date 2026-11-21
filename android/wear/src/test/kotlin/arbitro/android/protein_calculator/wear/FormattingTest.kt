package arbitro.android.protein_calculator.wear

import java.text.NumberFormat
import java.util.Locale
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

class FormattingTest {
    @Test
    fun `grams are rounded, a half up, as in the phone app`() {
        assertEquals(59, roundGrams(59.4))
        assertEquals(60, roundGrams(59.5))
        assertEquals(0, roundGrams(0.4))
        // Sums of decimals are not exact.
        assertEquals(60, roundGrams(59.999999999999))
        assertEquals(50, roundGrams(0.8 + 37.8 + 11.4))
    }

    @Test
    fun `the goal is reached once the total as shown reaches it`() {
        assertFalse(isGoalReached(139.4, 140.0))
        assertTrue(isGoalReached(139.5, 140.0))
        assertTrue(isGoalReached(0.8 + 37.8 + 11.4, 50.0))
    }

    @Test
    fun `grams are written in the language of the watch`() {
        assertEquals("1,235", formatGrams(1234.9, Locale.US))
        assertEquals(NumberFormat.getIntegerInstance(Locale.FRANCE).format(1234), formatGrams(1234.4, Locale.FRANCE))
        assertEquals("140", formatGrams(140.0, Locale.FRANCE))
    }

    @Test
    fun `a name typed is trimmed, and cut to the length the phone accepts`() {
        assertEquals("Oeufs", entryName("  Oeufs "))
        assertNull(entryName("   "))
        assertEquals("a".repeat(MAX_NAME_LENGTH), entryName("a".repeat(MAX_NAME_LENGTH + 5)))
        // Not cut in the middle of an emoji, nor ending with a space.
        assertEquals("a".repeat(MAX_NAME_LENGTH - 1), entryName("a".repeat(MAX_NAME_LENGTH - 1) + " b"))
        assertEquals("😀".repeat(MAX_NAME_LENGTH), entryName("😀".repeat(MAX_NAME_LENGTH + 1)))
    }

    @Test
    fun `the protein of a product has one decimal at most`() {
        assertEquals("10,5", formatProtein(10.5, Locale.FRANCE))
        assertEquals("10.5", formatProtein(10.5, Locale.US))
        assertEquals("23", formatProtein(23.0, Locale.FRANCE))
        assertEquals("12.3", formatProtein(12.34, Locale.US))
    }
}
