package arbitro.android.protein_calculator.wear

import java.time.LocalDateTime
import kotlin.test.Test
import kotlin.test.assertEquals

class AppDayTest {
    @Test
    fun `a day starts at the hour chosen`() {
        assertEquals(20261001, dayKeyOf(LocalDateTime.of(2026, 10, 1, 3, 0), 3))
        assertEquals(20260930, dayKeyOf(LocalDateTime.of(2026, 10, 1, 2, 59), 3))
        assertEquals(20261001, dayKeyOf(LocalDateTime.of(2026, 10, 1, 23, 59), 3))
    }

    @Test
    fun `a day starting at midnight is the calendar day`() {
        assertEquals(20261001, dayKeyOf(LocalDateTime.of(2026, 10, 1, 0, 0), 0))
        assertEquals(20260930, dayKeyOf(LocalDateTime.of(2026, 9, 30, 23, 59), 0))
    }

    @Test
    fun `the night belongs to the day before, across months and years`() {
        assertEquals(20251231, dayKeyOf(LocalDateTime.of(2026, 1, 1, 6, 0), 7))
        assertEquals(20280229, dayKeyOf(LocalDateTime.of(2028, 3, 1, 1, 0), 2))
    }

    @Test
    fun `the next day starts the day after at the hour chosen`() {
        assertEquals(LocalDateTime.of(2026, 10, 2, 3, 0), nextDayStart(LocalDateTime.of(2026, 10, 1, 9, 0), 3))
        assertEquals(LocalDateTime.of(2026, 10, 1, 3, 0), nextDayStart(LocalDateTime.of(2026, 10, 1, 2, 0), 3))
        assertEquals(LocalDateTime.of(2027, 1, 1, 0, 0), nextDayStart(LocalDateTime.of(2026, 12, 31, 0, 0), 0))
    }
}
