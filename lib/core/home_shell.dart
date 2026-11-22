import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:protein_calculator/core/providers.dart';
import 'package:protein_calculator/core/router.dart';
import 'package:protein_calculator/core/theme.dart';
import 'package:protein_calculator/core/widgets/knit.dart';
import 'package:protein_calculator/core/widgets/shaker_icon.dart';
import 'package:protein_calculator/core/widgets/sliding_selector.dart';
import 'package:protein_calculator/core/widgets/snow.dart';
import 'package:protein_calculator/l10n/app_localizations.dart';

/// Tab bar scaffold shared by the five main tabs.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  /// Tapping the active tab again brings it back to its root page, closing
  /// any sheet or dialog open over it.
  void _select(int index) {
    if (index == navigationShell.currentIndex) {
      navigationShell.route.branches[index].navigatorKey.currentState?.popUntil(
        (route) => route is! PopupRoute,
      );
    }
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final christmas = ref.watch(christmasActiveProvider);
    final tabs = [
      (const ShakerIcon(), l10n.tabToday),
      (const Icon(LucideIcons.shoppingBasket), l10n.tabProducts),
      (const Icon(LucideIcons.history), l10n.tabHistory),
      (const Icon(LucideIcons.chartColumn), l10n.tabStats),
      (const Icon(LucideIcons.menu), l10n.tabMenu),
    ];
    final bar = _TabBar(
      tabs: tabs,
      selectedIndex: navigationShell.currentIndex,
      onSelected: _select,
      addLabel: l10n.addEntry,
      onAdd: () => context.push(AppRoutes.newEntry),
      // In landscape, height is scarce: the bar stands on the left.
      vertical: MediaQuery.orientationOf(context) == Orientation.landscape,
      knitted: christmas,
    );
    // From December 1 to 25, snow falls over the pages, behind the tab bar,
    // and settles at their foot.
    // Always in the same stack, so turning the theme on or off from the menu
    // keeps the pages and their state.
    final pages = Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: navigationShell),
        if (christmas) ...[
          const Positioned.fill(child: Snowfall()),
          const Positioned(left: 0, right: 0, bottom: 0, child: SnowBank()),
        ],
      ],
    );
    return bar.vertical
        ? Scaffold(
            body: Row(
              children: [
                bar,
                // The bar already keeps clear of the left edge cutouts.
                Expanded(
                  child: MediaQuery.removePadding(
                    context: context,
                    removeLeft: true,
                    child: pages,
                  ),
                ),
              ],
            ),
          )
        : Scaffold(body: pages, bottomNavigationBar: bar);
  }
}

/// Floating pill of tab icons, next to a round button adding an entry from
/// any tab: at the bottom, or on the left when [vertical].
class _TabBar extends StatelessWidget {
  const _TabBar({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
    required this.addLabel,
    required this.onAdd,
    required this.vertical,
    this.knitted = false,
  });

  /// Knitted motif of each tab, in the order of [tabs].
  static const _motifs = [
    KnitMotifs.today,
    KnitMotifs.products,
    KnitMotifs.history,
    KnitMotifs.stats,
    KnitMotifs.menu,
  ];

  final List<(Widget, String)> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final String addLabel;
  final VoidCallback onAdd;
  final bool vertical;

  /// Whether the pill and the add button are knitted, for Christmas.
  final bool knitted;

  /// Thickness of the pill and size of the add button.
  static const _thickness = 60.0;

  /// Length of a tab in the vertical pill, shortened down to
  /// [_minTabLength] on a screen too low for all the tabs.
  static const _tabLength = 46.0;
  static const _minTabLength = 40.0;
  static const _gap = 4.0;

  @override
  Widget build(BuildContext context) {
    if (!vertical) return _build(context, _tabLength);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Room left for the tabs once the system bars, the padding, the add
        // button, the space before it and the padding of the pill are set
        // aside.
        final room =
            constraints.maxHeight -
            MediaQuery.paddingOf(context).vertical -
            24 -
            _thickness -
            12 -
            12 +
            _gap;
        return _build(
          context,
          (room / tabs.length - _gap).clamp(_minTabLength, _tabLength),
        );
      },
    );
  }

  Widget _build(BuildContext context, double tabLength) {
    final colors = AppColors.of(context);
    final direction = vertical ? Axis.vertical : Axis.horizontal;

    final pillWidth = vertical ? _thickness : null;
    final pillHeight = vertical
        ? tabs.length * (tabLength + _gap) - _gap + 12
        : _thickness;
    final pill = knitted
        ? _knittedPill(context, pillWidth, pillHeight, direction)
        : Container(
            width: pillWidth,
            height: pillHeight,
            padding: const EdgeInsets.all(6),
            decoration: ShapeDecoration(
              color: colors.surface,
              shape: StadiumBorder(side: BorderSide(color: colors.divider)),
            ),
            child: SlidingSelector(
              selectedIndex: selectedIndex,
              gap: _gap,
              direction: direction,
              shape: const StadiumBorder(),
              children: [
                for (final (index, (icon, label)) in tabs.indexed)
                  _Tab(
                    icon: icon,
                    label: label,
                    selected: index == selectedIndex,
                    onTap: () => onSelected(index),
                  ),
              ],
            ),
          );
    final addButton = knitted
        ? _knittedAddButton(colors)
        : SizedBox.square(
            dimension: _thickness,
            child: IconButton.filled(
              onPressed: onAdd,
              tooltip: addLabel,
              style: IconButton.styleFrom(
                backgroundColor: colors.accent,
                foregroundColor: colors.onAccent,
              ),
              icon: const Icon(LucideIcons.plus, size: 28),
            ),
          );

    return ColoredBox(
      // At the bottom, the knitted bar lies in the snow of the bank above it.
      color: knitted && !vertical ? snowWhite : colors.background,
      child: SafeArea(
        top: vertical,
        right: !vertical,
        child: Padding(
          padding: vertical
              ? const EdgeInsets.fromLTRB(12, 12, 4, 12)
              : const EdgeInsets.fromLTRB(16, 6, 16, 12),
          child: Flex(
            direction: direction,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (vertical) pill else Expanded(child: pill),
              SizedBox(
                width: vertical ? null : 12,
                height: vertical ? 12 : null,
              ),
              addButton,
            ],
          ),
        ),
      ),
    );
  }

  /// The pill knitted for Christmas, see [KnitTabBackground]: the tabs stay
  /// for the touches, the tooltips and screen readers, their icons knitted
  /// in the wool instead of drawn over it.
  Widget _knittedPill(
    BuildContext context,
    double? width,
    double? height,
    Axis direction,
  ) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 250);
    return Container(
      width: width,
      height: height,
      decoration: const ShapeDecoration(shape: StadiumBorder()),
      clipBehavior: Clip.antiAlias,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: selectedIndex.toDouble()),
        duration: duration,
        curve: Curves.easeOutCubic,
        builder: (context, selection, child) => CustomPaint(
          painter: KnitTabBackground(
            colors: AppColors.of(context),
            motifs: _motifs,
            selection: selection,
            vertical: vertical,
            padding: 6,
            gap: _gap,
          ),
          child: child,
        ),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Flex(
            direction: direction,
            children: [
              for (final (index, (icon, label)) in tabs.indexed) ...[
                if (index > 0)
                  SizedBox(
                    width: vertical ? null : _gap,
                    height: vertical ? _gap : null,
                  ),
                Expanded(
                  child: _Tab(
                    icon: icon,
                    label: label,
                    selected: index == selectedIndex,
                    knitted: true,
                    onTap: () => onSelected(index),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// The add button knitted in red, with a white plus.
  Widget _knittedAddButton(AppColors colors) => Tooltip(
    message: addLabel,
    child: Semantics(
      button: true,
      child: Material(
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onAdd,
          child: CustomPaint(
            size: const Size.square(_thickness),
            painter: KnitButtonPainter(colors),
          ),
        ),
      ),
    ),
  );
}

/// Icon of a tab; its name shows as a tooltip and is read by screen readers.
class _Tab extends StatelessWidget {
  const _Tab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.knitted = false,
  });

  final Widget icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Whether the icon is knitted in the pill rather than drawn: the tab
  /// then only takes the touches.
  final bool knitted;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Center(
              child: IconTheme(
                data: IconThemeData(
                  size: 22,
                  color: knitted
                      ? Colors.transparent
                      : selected
                      ? AppColors.of(context).onAccent
                      : AppColors.of(context).textSecondary,
                ),
                child: icon,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
