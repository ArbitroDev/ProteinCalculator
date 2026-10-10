package arbitro.android.protein_calculator.wear

import android.text.format.DateUtils
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.animateScrollBy
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.calculateEndPadding
import androidx.compose.foundation.layout.calculateStartPadding
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.wear.compose.foundation.lazy.TransformingLazyColumn
import androidx.wear.compose.foundation.lazy.TransformingLazyColumnItemScope
import androidx.wear.compose.foundation.lazy.TransformingLazyColumnState
import androidx.wear.compose.foundation.lazy.items
import androidx.wear.compose.foundation.lazy.rememberTransformingLazyColumnState
import androidx.wear.compose.material3.AppScaffold
import androidx.wear.compose.material3.ConfirmationDialog
import androidx.wear.compose.material3.ConfirmationDialogDefaults
import androidx.wear.compose.material3.ListHeader
import androidx.wear.compose.material3.ScreenScaffold
import androidx.wear.compose.material3.Text
import androidx.wear.compose.material3.lazy.TransformationSpec
import androidx.wear.compose.material3.lazy.rememberTransformationSpec
import androidx.wear.compose.material3.lazy.transformedHeight
import androidx.wear.compose.navigation.SwipeDismissableNavHost
import androidx.wear.compose.navigation.composable
import androidx.wear.compose.navigation.rememberSwipeDismissableNavController
import arbitro.android.protein_calculator.protocol.WatchProduct

/** Routes of the screens of the app. */
private object Routes {
    const val DAY = "day"
    const val PRODUCTS = "products"
}

@Composable
fun WatchApp(
    screen: WatchScreen,
    added: WatchViewModel.Added?,
    onAdd: (WatchProduct) -> Unit,
    onDismissAdded: () -> Unit,
) {
    AppScaffold {
        val navController = rememberSwipeDismissableNavController()
        // The screens of the graph, built once, read the latest state.
        val current by rememberUpdatedState(screen)
        SwipeDismissableNavHost(navController, startDestination = Routes.DAY) {
            composable(Routes.DAY) {
                DayScreen(current, onOpenProducts = { navController.navigate(Routes.PRODUCTS) })
            }
            composable(Routes.PRODUCTS) {
                ProductsScreen(
                    products = (current as? WatchScreen.Day)?.products.orEmpty(),
                    onAdd = { product ->
                        onAdd(product)
                        navController.popBackStack()
                    },
                )
            }
        }
        AddedConfirmation(added, onDismissAdded)
    }
}

/** The day: its summary, the button to add a product, then its entries. */
@Composable
private fun DayScreen(screen: WatchScreen, onOpenProducts: () -> Unit) {
    val listState = rememberTransformingLazyColumnState()
    // Items shrink near the round edges of the screen instead of being cut.
    val transformation = rememberTransformationSpec()
    ScreenScaffold(scrollState = listState) { scaffoldPadding ->
        BoxWithConstraints(Modifier.fillMaxSize().background(WatchColors.background)) {
            val viewport = maxHeight
            // The summary of the day starts at the very top, around the time.
            val contentPadding = if (screen is WatchScreen.Day) {
                listPadding(scaffoldPadding, maxWidth, viewport, top = 0.dp, bottom = DAY_BOTTOM_PADDING)
            } else {
                scaffoldPadding
            }
            if (screen is WatchScreen.Day) SnapHero(listState, viewport)
            TransformingLazyColumn(
                state = listState,
                contentPadding = contentPadding,
                modifier = Modifier.fillMaxSize(),
            ) {
                when (screen) {
                    WatchScreen.Loading -> Unit
                    WatchScreen.OpenPhone -> item { Message(stringResource(R.string.open_phone)) }
                    is WatchScreen.Incompatible -> item {
                        Message(
                            stringResource(
                                when (screen.incompatibility) {
                                    Incompatibility.UPDATE_WATCH -> R.string.update_watch
                                    Incompatibility.UPDATE_PHONE -> R.string.update_phone
                                },
                            ),
                        )
                    }
                    is WatchScreen.Day -> {
                        item(key = "day") { DayHero(screen, maxWidth, viewport) }
                        item(key = "today") {
                            ListHeader(Modifier.transformed(this, transformation)) {
                                Text(stringResource(R.string.today))
                            }
                        }
                        if (screen.entries.isEmpty()) {
                            item { Hint(stringResource(R.string.no_entries)) }
                        }
                        items(screen.entries) {
                            EntryRow(it, Modifier.transformed(this, transformation))
                        }
                        // Last, in the space below the entries, near the bottom edge.
                        item(key = "add") { AddButton(onOpenProducts) }
                    }
                }
            }
        }
    }
}

/** The saved products, the favorite first: a tap adds one portion. */
@Composable
private fun ProductsScreen(products: List<WatchProduct>, onAdd: (WatchProduct) -> Unit) {
    val listState = rememberTransformingLazyColumnState()
    val transformation = rememberTransformationSpec()
    ScreenScaffold(scrollState = listState) { scaffoldPadding ->
        BoxWithConstraints(Modifier.fillMaxSize().background(WatchColors.background)) {
            TransformingLazyColumn(
                state = listState,
                contentPadding = listPadding(
                    scaffoldPadding,
                    maxWidth,
                    maxHeight,
                    top = scaffoldPadding.calculateTopPadding(),
                    bottom = BOTTOM_PADDING,
                ),
                modifier = Modifier.fillMaxSize(),
            ) {
                item {
                    ListHeader(Modifier.transformed(this, transformation)) {
                        Text(stringResource(R.string.products))
                    }
                }
                if (products.isEmpty()) {
                    item { Hint(stringResource(R.string.no_products)) }
                }
                items(products, key = { it.id }) {
                    ProductRow(it, onAdd, Modifier.transformed(this, transformation))
                }
            }
        }
    }
}

/**
 * Padding of a list: clear of the round edges on the sides, and [bottom]
 * (against the height of the screen) below the last item.
 */
@Composable
private fun listPadding(
    scaffoldPadding: PaddingValues,
    width: Dp,
    height: Dp,
    top: Dp,
    bottom: Float,
): PaddingValues {
    val direction = LocalLayoutDirection.current
    val side = width * SIDE_PADDING
    return PaddingValues(
        start = maxOf(scaffoldPadding.calculateStartPadding(direction), side),
        top = top,
        end = maxOf(scaffoldPadding.calculateEndPadding(direction), side),
        bottom = maxOf(scaffoldPadding.calculateBottomPadding(), height * bottom),
    )
}

/** Round button opening the products, to add one. */
@Composable
private fun AddButton(onClick: () -> Unit) {
    val add = stringResource(R.string.add)
    Box(Modifier.fillMaxWidth().padding(top = 8.dp), contentAlignment = Alignment.Center) {
        Box(
            modifier = Modifier
                .size(52.dp)
                .clip(CircleShape)
                .background(WatchColors.accent)
                .clickable(role = Role.Button, onClickLabel = add, onClick = onClick)
                .semantics { contentDescription = add },
            contentAlignment = Alignment.Center,
        ) {
            Canvas(Modifier.size(20.dp)) {
                val stroke = 3.dp.toPx()
                val middle = size.width / 2
                drawLine(WatchColors.onAccent, Offset(middle, 0f), Offset(middle, size.height), stroke, StrokeCap.Round)
                drawLine(WatchColors.onAccent, Offset(0f, middle), Offset(size.width, middle), stroke, StrokeCap.Round)
            }
        }
    }
}

/**
 * An entry of the day: its name, its time and its grams. A watch marks those
 * added on the watch; those the phone has not made yet say so instead of
 * their time.
 */
@Composable
private fun EntryRow(entry: DayEntry, modifier: Modifier) {
    val fonts = LocalWatchFonts.current
    val context = LocalContext.current
    val locale = LocalConfiguration.current.locales[0]
    Row(
        modifier = modifier
            .fillMaxWidth()
            .background(WatchColors.surface, RoundedCornerShape(18.dp))
            .padding(horizontal = 14.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Column(Modifier.weight(1f)) {
            Text(
                entry.name ?: stringResource(R.string.unnamed),
                style = if (entry.name == null) fonts.body.copy(fontStyle = FontStyle.Italic) else fonts.body,
                color = if (entry.name == null) WatchColors.textSecondary else WatchColors.text,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                if (entry.pending) {
                    Text(stringResource(R.string.entry_waiting), style = fonts.caption, color = WatchColors.accent)
                } else {
                    Text(
                        DateUtils.formatDateTime(context, entry.time, DateUtils.FORMAT_SHOW_TIME),
                        style = fonts.caption,
                        color = WatchColors.textSecondary,
                    )
                }
                if (entry.fromWatch) {
                    val fromWatch = stringResource(R.string.from_watch)
                    WatchGlyph(
                        color = if (entry.pending) WatchColors.accent else WatchColors.textSecondary,
                        modifier = Modifier
                            .size(width = 8.dp, height = 11.dp)
                            .semantics { contentDescription = fromWatch },
                    )
                }
            }
        }
        Text(
            stringResource(R.string.grams, formatProtein(entry.protein, locale)),
            style = fonts.value,
            color = WatchColors.text,
        )
    }
}

/** A small watch: round case and strap. */
@Composable
private fun WatchGlyph(color: Color, modifier: Modifier) {
    Canvas(modifier) {
        val stroke = size.width * 0.16f
        val strap = size.width * 0.5f
        // Strap, above and below the case.
        drawRect(color, Offset((size.width - strap) / 2, 0f), Size(strap, size.height))
        val case = size.width
        drawRoundRect(
            color,
            topLeft = Offset(stroke / 2, (size.height - case) / 2 + stroke / 2),
            size = Size(case - stroke, case - stroke),
            cornerRadius = CornerRadius(case * 0.3f),
            style = Stroke(stroke),
        )
        drawRoundRect(
            WatchColors.surface,
            topLeft = Offset(stroke, (size.height - case) / 2 + stroke),
            size = Size(case - stroke * 2, case - stroke * 2),
            cornerRadius = CornerRadius(case * 0.2f),
        )
    }
}

/**
 * Confirms a portion added on the watch, and tells when it waits for the
 * phone to be nearby.
 */
@Composable
private fun AddedConfirmation(added: WatchViewModel.Added?, onDismiss: () -> Unit) {
    val locale = LocalConfiguration.current.locales[0]
    val fonts = LocalWatchFonts.current
    // Kept while the dialog fades out.
    var shown by remember { mutableStateOf(added) }
    if (added != null) shown = added
    ConfirmationDialog(
        visible = added != null,
        onDismissRequest = onDismiss,
        colors = ConfirmationDialogDefaults.colors(
            iconContainerColor = WatchColors.surface,
            iconColor = WatchColors.accent,
            textColor = WatchColors.text,
        ),
        text = {
            val product = shown?.product ?: return@ConfirmationDialog
            Text(
                stringResource(R.string.added, formatProtein(product.protein, locale)) + " · " + product.name,
                style = fonts.body,
                color = WatchColors.text,
                textAlign = TextAlign.Center,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
            if (shown?.phoneNearby == false) {
                Text(
                    stringResource(R.string.added_later),
                    style = fonts.caption,
                    color = WatchColors.textSecondary,
                    textAlign = TextAlign.Center,
                )
            }
        },
    ) {
        Shaker(1f, Modifier.size(width = 30.dp, height = 50.dp))
    }
}

/** Space on each side of the lists, against the width of the screen. */
private const val SIDE_PADDING = 0.06f

/** Space below the last product, against the height of the screen: it can scroll up to the middle. */
private const val BOTTOM_PADDING = 0.3f

/** Space below the add button, ending the day, against the height of the screen. */
private const val DAY_BOTTOM_PADDING = 0.06f

/**
 * A scroll never stops while the summary of the day shrinks: it goes back
 * to the edge of the screen, or ends shrunk.
 */
@Composable
private fun SnapHero(listState: TransformingLazyColumnState, viewportHeight: Dp) {
    val viewport = with(LocalDensity.current) { viewportHeight.toPx() }
    LaunchedEffect(listState, viewport) {
        snapshotFlow { listState.isScrollInProgress }.collect { scrolling ->
            if (scrolling) return@collect
            val layout = listState.layoutInfo
            val hero = layout.visibleItems.firstOrNull { it.index == 0 } ?: return@collect
            val collapse = viewport * HERO_COLLAPSE
            val scrolled = (layout.beforeContentPadding - hero.offset).toFloat()
            if (scrolled > 0f && scrolled < collapse) {
                listState.animateScrollBy(if (scrolled < collapse / 2) -scrolled else collapse - scrolled)
            }
        }
    }
}

/** Shrinks and fades an item near the round edges of the screen, as [spec] says. */
private fun Modifier.transformed(scope: TransformingLazyColumnItemScope, spec: TransformationSpec) =
    with(scope) {
        transformedHeight(scope, spec).graphicsLayer {
            with(spec) {
                applyContainerTransformation(scrollProgress)
                applyContentTransformation(scrollProgress)
            }
        }
    }

/** A product, adding one portion when tapped. */
@Composable
private fun ProductRow(product: WatchProduct, onAdd: (WatchProduct) -> Unit, modifier: Modifier) {
    val fonts = LocalWatchFonts.current
    val locale = LocalConfiguration.current.locales[0]
    val haptics = LocalHapticFeedback.current
    val shape = RoundedCornerShape(26.dp)
    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(shape)
            .background(WatchColors.surface, shape)
            .clickable(onClickLabel = stringResource(R.string.add_portion), role = Role.Button) {
                haptics.performHapticFeedback(HapticFeedbackType.Confirm)
                onAdd(product)
            }
            .padding(horizontal = 14.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        if (product.favorite) {
            val favorite = stringResource(R.string.favorite)
            Text(
                "★",
                style = fonts.body,
                color = WatchColors.accent,
                modifier = Modifier.semantics { contentDescription = favorite },
            )
        }
        Text(
            product.name,
            style = fonts.body,
            color = WatchColors.text,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f),
        )
        Text(
            stringResource(R.string.grams, formatProtein(product.protein, locale)),
            style = fonts.value,
            color = WatchColors.text,
        )
    }
}

@Composable
private fun Message(text: String) {
    Column(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Shaker(0f, Modifier.size(width = 28.dp, height = 48.dp))
        Spacer(Modifier.size(8.dp))
        Hint(text)
    }
}

@Composable
private fun Hint(text: String) {
    Text(
        text,
        style = LocalWatchFonts.current.body,
        color = WatchColors.textSecondary,
        textAlign = TextAlign.Center,
        modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp),
    )
}
