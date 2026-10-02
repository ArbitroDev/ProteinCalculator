import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:protein_calculator/core/router.dart';
import 'package:protein_calculator/core/theme.dart';
import 'package:protein_calculator/core/widgets/sliding_selector.dart';
import 'package:protein_calculator/l10n/app_localizations.dart';

/// Tab bar scaffold shared by the four main tabs.
class HomeShell extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tabs = [
      (LucideIcons.calendarDays, l10n.tabToday),
      (LucideIcons.history, l10n.tabHistory),
      (LucideIcons.shoppingBasket, l10n.tabProducts),
      (LucideIcons.menu, l10n.tabMenu),
    ];
    final bar = _TabBar(
      tabs: tabs,
      selectedIndex: navigationShell.currentIndex,
      onSelected: _select,
      addLabel: l10n.addEntry,
      onAdd: () => context.push(AppRoutes.newEntry),
      // In landscape, height is scarce: the bar stands on the left.
      vertical: MediaQuery.orientationOf(context) == Orientation.landscape,
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
                    child: navigationShell,
                  ),
                ),
              ],
            ),
          )
        : Scaffold(body: navigationShell, bottomNavigationBar: bar);
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
  });

  final List<(IconData, String)> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final String addLabel;
  final VoidCallback onAdd;
  final bool vertical;

  /// Thickness of the pill and size of the add button.
  static const _thickness = 60.0;

  /// Length of a tab in the vertical pill.
  static const _tabLength = 46.0;
  static const _gap = 4.0;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final direction = vertical ? Axis.vertical : Axis.horizontal;

    final pill = Container(
      width: vertical ? _thickness : null,
      height: vertical
          ? tabs.length * (_tabLength + _gap) - _gap + 12
          : _thickness,
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
    final addButton = SizedBox.square(
      dimension: _thickness,
      child: IconButton.filled(
        onPressed: onAdd,
        tooltip: addLabel,
        style: IconButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.onAccent,
        ),
        icon: const Icon(LucideIcons.plus, size: 28),
      ),
    );

    return ColoredBox(
      color: colors.background,
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
}

/// Icon of a tab; its name shows as a tooltip and is read by screen readers.
class _Tab extends StatelessWidget {
  const _Tab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

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
              child: Icon(
                icon,
                size: 22,
                color: selected
                    ? AppColors.onAccent
                    : AppColors.of(context).textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
