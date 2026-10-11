package arbitro.android.protein_calculator.wear

import android.app.RemoteInput
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material3.Button
import androidx.wear.compose.material3.ButtonDefaults
import androidx.wear.compose.material3.CompactButton
import androidx.wear.compose.material3.Picker
import androidx.wear.compose.material3.PickerState
import androidx.wear.compose.material3.Text
import androidx.wear.input.RemoteInputIntentHelper

/** Grams a free entry starts at, the first time. */
const val FREE_GRAMS_START = 20

/** Most grams of a free entry, three digits on the keypad. */
private const val FREE_GRAMS_MAX = 999

/** Key of the name typed or dictated in the result of the input. */
private const val NAME_KEY = "name"

/** First row of the products: a free entry, of the grams chosen. */
@Composable
fun FreeEntryRow(onClick: () -> Unit, modifier: Modifier) {
    val fonts = LocalWatchFonts.current
    val shape = RoundedCornerShape(26.dp)
    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(shape)
            .background(WatchColors.surface, shape)
            .clickable(role = Role.Button, onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Text("+", style = fonts.button, color = WatchColors.accent)
        Text(
            stringResource(R.string.free_entry),
            style = fonts.body,
            color = WatchColors.text,
            modifier = Modifier.weight(1f),
        )
        Text(stringResource(R.string.grams, "…"), style = fonts.value, color = WatchColors.textSecondary)
    }
}

/**
 * Grams of a free entry, on a wheel turned by the crown or by the finger,
 * one gram a notch; a tap on it opens the keypad.
 */
@Composable
fun FreeGramsScreen(grams: Int, onGramsChange: (Int) -> Unit, onType: () -> Unit, onNext: () -> Unit) {
    val fonts = LocalWatchFonts.current
    // Made again each time the screen shows, at the grams kept by the app:
    // those typed on the keypad included.
    val state = remember { PickerState(FREE_GRAMS_MAX, grams - 1, shouldRepeatOptions = false) }
    val current by rememberUpdatedState(grams)
    val change by rememberUpdatedState(onGramsChange)
    LaunchedEffect(state) {
        snapshotFlow { state.selectedOptionIndex + 1 }.collect { if (it != current) change(it) }
    }
    val description = stringResource(R.string.free_entry)
    val type = stringResource(R.string.type_grams)
    Box(Modifier.fillMaxSize().background(WatchColors.background), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Picker(
                state = state,
                contentDescription = { "$description, ${state.selectedOptionIndex + 1} g" },
                modifier = Modifier.size(width = 140.dp, height = 104.dp),
                onSelected = onType,
                gradientColor = WatchColors.background,
            ) { index ->
                val selected = index == state.selectedOptionIndex
                // All the options take the same height, the wheel stops on
                // their middle: the others only show smaller.
                Box(
                    modifier = Modifier
                        .height(OPTION_HEIGHT)
                        .graphicsLayer {
                            if (!selected) {
                                scaleX = OTHER_OPTION_SCALE
                                scaleY = OTHER_OPTION_SCALE
                            }
                        }
                        .then(if (selected) Modifier.clickable(onClickLabel = type, onClick = onType) else Modifier),
                    contentAlignment = Alignment.Center,
                ) {
                    Row {
                        Text(
                            (index + 1).toString(),
                            style = fonts.total,
                            color = if (selected) WatchColors.text else WatchColors.textSecondary,
                            modifier = Modifier.alignByBaseline(),
                        )
                        if (selected) {
                            Text(" g", style = fonts.unit, color = WatchColors.text, modifier = Modifier.alignByBaseline())
                        }
                    }
                }
            }
            Text(
                stringResource(R.string.free_grams_hint),
                style = fonts.caption,
                color = WatchColors.accent,
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .clip(RoundedCornerShape(8.dp))
                    .clickable(role = Role.Button, onClickLabel = type, onClick = onType)
                    .padding(horizontal = 8.dp, vertical = 4.dp),
            )
            Spacer(Modifier.height(4.dp))
            CompactButton(
                onClick = onNext,
                colors = ButtonDefaults.buttonColors(
                    containerColor = WatchColors.accent,
                    contentColor = WatchColors.onAccent,
                ),
            ) {
                Text(stringResource(R.string.next), style = fonts.button)
            }
        }
    }
}

/** Height of each grams on the wheel. */
private val OPTION_HEIGHT = 46.dp

/** Size of the grams around the one chosen, against it. */
private const val OTHER_OPTION_SCALE = 0.58f

/** Digits of the grams, typed on a keypad: [onDone] gets them. */
@Composable
fun KeypadScreen(onDone: (Int) -> Unit) {
    val fonts = LocalWatchFonts.current
    var typed by rememberSaveable { mutableStateOf("") }
    val grams = typed.toIntOrNull()?.takeIf { it in 1..FREE_GRAMS_MAX }
    fun type(digit: Char) {
        if (typed.length < FREE_GRAMS_MAX.toString().length) typed = (typed + digit).trimStart('0')
    }
    Box(Modifier.fillMaxSize().background(WatchColors.background), contentAlignment = Alignment.Center) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(3.dp),
        ) {
            Text(
                if (typed.isEmpty()) "– g" else "$typed g",
                style = fonts.unit,
                color = if (typed.isEmpty()) WatchColors.textSecondary else WatchColors.text,
            )
            for (row in listOf("123", "456", "789")) {
                Row(horizontalArrangement = Arrangement.spacedBy(3.dp)) {
                    for (digit in row) Key(digit.toString(), onClick = { type(digit) })
                }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(3.dp)) {
                Key("⌫", label = stringResource(R.string.erase), onClick = { typed = typed.dropLast(1) })
                Key("0", onClick = { type('0') })
                Key(
                    "✓",
                    label = stringResource(R.string.done),
                    enabled = grams != null,
                    color = WatchColors.accent,
                    textColor = WatchColors.onAccent,
                    onClick = { grams?.let(onDone) },
                )
            }
        }
    }
}

@Composable
private fun Key(
    text: String,
    onClick: () -> Unit,
    label: String? = null,
    enabled: Boolean = true,
    color: Color = WatchColors.surface,
    textColor: Color = WatchColors.text,
) {
    val shape = RoundedCornerShape(14.dp)
    Box(
        modifier = Modifier
            .size(width = 38.dp, height = 28.dp)
            .clip(shape)
            .background(if (enabled) color else WatchColors.surface, shape)
            .clickable(enabled = enabled, role = Role.Button, onClick = onClick)
            .semantics { if (label != null) contentDescription = label },
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text,
            style = LocalWatchFonts.current.value,
            color = if (enabled) textColor else WatchColors.textSecondary,
        )
    }
}

/**
 * Last step of a free entry of [grams]: a name can be typed or dictated,
 * as Wear OS offers, then shown to be checked or changed before adding.
 */
@Composable
fun FreeNameScreen(grams: Int, onAdd: (name: String?) -> Unit) {
    val fonts = LocalWatchFonts.current
    val locale = LocalConfiguration.current.locales[0]
    var name by rememberSaveable { mutableStateOf<String?>(null) }
    val nameLabel = stringResource(R.string.entry_name)
    val input = rememberLauncherForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
        val text = result.data?.let { RemoteInput.getResultsFromIntent(it) }?.getCharSequence(NAME_KEY)
        // Nothing typed keeps the name there was.
        entryName(text?.toString().orEmpty())?.let { name = it }
    }
    fun typeName() {
        val intent = RemoteInputIntentHelper.createActionRemoteInputIntent()
        RemoteInputIntentHelper.putRemoteInputsExtra(
            intent,
            listOf(RemoteInput.Builder(NAME_KEY).setLabel(nameLabel).build()),
        )
        input.launch(intent)
    }
    Box(Modifier.fillMaxSize().background(WatchColors.background), contentAlignment = Alignment.Center) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier.padding(horizontal = 24.dp),
        ) {
            Row {
                Text(
                    formatGrams(grams.toDouble(), locale),
                    style = fonts.total,
                    color = WatchColors.text,
                    modifier = Modifier.alignByBaseline(),
                )
                Text(" g", style = fonts.unit, color = WatchColors.text, modifier = Modifier.alignByBaseline())
            }
            Spacer(Modifier.height(6.dp))
            // The name, or the link to give one: a tap types it again.
            val current = name
            Text(
                current ?: stringResource(R.string.add_name),
                style = if (current == null) fonts.caption else fonts.body,
                color = if (current == null) WatchColors.accent else WatchColors.text,
                textAlign = TextAlign.Center,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier
                    .clip(RoundedCornerShape(8.dp))
                    .clickable(
                        role = Role.Button,
                        onClickLabel = stringResource(if (current == null) R.string.add_name else R.string.change_name),
                        onClick = ::typeName,
                    )
                    .padding(horizontal = 8.dp, vertical = 4.dp),
            )
            Spacer(Modifier.height(6.dp))
            CompactButton(
                onClick = { onAdd(name) },
                colors = ButtonDefaults.buttonColors(
                    containerColor = WatchColors.accent,
                    contentColor = WatchColors.onAccent,
                ),
            ) {
                Text(stringResource(R.string.add), style = fonts.button)
            }
        }
    }
}
