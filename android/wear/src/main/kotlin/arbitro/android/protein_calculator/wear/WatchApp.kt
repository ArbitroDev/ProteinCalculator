package arbitro.android.protein_calculator.wear

import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.animateScrollBy
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.calculateEndPadding
import androidx.compose.foundation.layout.calculateStartPadding
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
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
import androidx.wear.compose.material3.ListHeader
import androidx.wear.compose.material3.ScreenScaffold
import androidx.wear.compose.material3.Text
import androidx.wear.compose.material3.lazy.TransformationSpec
import androidx.wear.compose.material3.lazy.rememberTransformationSpec
import androidx.wear.compose.material3.lazy.transformedHeight
import arbitro.android.protein_calculator.protocol.WatchProduct

@Composable
fun WatchApp(screen: WatchScreen) {
    AppScaffold {
        val listState = rememberTransformingLazyColumnState()
        // Items shrink near the round edges of the screen instead of being cut.
        val transformation = rememberTransformationSpec()
        ScreenScaffold(scrollState = listState) { scaffoldPadding ->
            BoxWithConstraints(Modifier.fillMaxSize().background(WatchColors.background)) {
                val viewport = maxHeight
                // The summary of the day starts at the very top, around the time.
                // The products keep clear of the round edges, the last one can
                // scroll up to the middle of the screen.
                val contentPadding = if (screen is WatchScreen.Day) {
                    val direction = LocalLayoutDirection.current
                    val side = maxWidth * SIDE_PADDING
                    PaddingValues(
                        start = maxOf(scaffoldPadding.calculateStartPadding(direction), side),
                        end = maxOf(scaffoldPadding.calculateEndPadding(direction), side),
                        bottom = maxOf(scaffoldPadding.calculateBottomPadding(), viewport * BOTTOM_PADDING),
                    )
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
                            item(key = "products") {
                                ListHeader(Modifier.transformed(this, transformation)) {
                                    Text(stringResource(R.string.products))
                                }
                            }
                            if (screen.products.isEmpty()) {
                                item { Hint(stringResource(R.string.no_products)) }
                            }
                            items(screen.products, key = { it.id }) {
                                ProductRow(it, Modifier.transformed(this, transformation))
                            }
                        }
                    }
                }
            }
        }
    }
}

/** Space on each side of the products, against the width of the screen. */
private const val SIDE_PADDING = 0.06f

/** Space below the last product, against the height of the screen. */
private const val BOTTOM_PADDING = 0.3f

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

@Composable
private fun ProductRow(product: WatchProduct, modifier: Modifier) {
    val fonts = LocalWatchFonts.current
    val locale = LocalConfiguration.current.locales[0]
    Row(
        modifier = modifier
            .fillMaxWidth()
            .background(WatchColors.surface, RoundedCornerShape(26.dp))
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
