package arbitro.android.protein_calculator.wear

import androidx.annotation.DrawableRes
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material3.Icon
import androidx.wear.compose.material3.Text

/**
 * Marks of the day, after its goal: the creatine doses taken and the Hevy
 * workouts, each with their number when there are several, as the tile
 * shows them. Nothing for what the day has none of.
 */
@Composable
fun DayMarks(day: WatchScreen.Day, style: TextStyle) {
    if (day.creatineDoses == 0 && day.hevyWorkouts == 0) return
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        if (day.creatineDoses > 0) {
            CountMark(
                drawable = R.drawable.ic_creatine,
                color = WatchColors.creatine,
                count = day.creatineDoses,
                description = pluralStringResource(R.plurals.creatine_doses, day.creatineDoses, day.creatineDoses),
                style = style,
            )
        }
        if (day.hevyWorkouts > 0) {
            CountMark(
                drawable = R.drawable.ic_dumbbell,
                color = WatchColors.hevy,
                count = day.hevyWorkouts,
                description = pluralStringResource(R.plurals.hevy_workouts, day.hevyWorkouts, day.hevyWorkouts),
                style = style,
            )
        }
    }
}

/** [drawable] in [color], then "×N" when [count] is above one, read as [description]. */
@Composable
private fun CountMark(@DrawableRes drawable: Int, color: Color, count: Int, description: String, style: TextStyle) {
    Row(
        modifier = Modifier.semantics(mergeDescendants = true) { contentDescription = description },
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            painter = painterResource(drawable),
            contentDescription = null,
            tint = color,
            modifier = Modifier.size(14.dp),
        )
        if (count > 1) Text("×$count", style = style, color = color)
    }
}
