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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tabs = [
      (LucideIcons.calendarDays, l10n.tabToday),
      (LucideIcons.history, l10n.tabHistory),
      (LucideIcons.shoppingBasket, l10n.tabProducts),
      (LucideIcons.menu, l10n.tabMenu),
    ];
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: _TabBar(
        tabs: tabs,
        selectedIndex: navigationShell.currentIndex,
        // Tapping the active tab again brings it back to its root page.
        onSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        addLabel: l10n.addEntry,
        onAdd: () => context.push(AppRoutes.newEntry),
      ),
    );
  }
}

/// Floating pill of tab icons, next to a round button adding an entry from
/// any tab.
class _TabBar extends StatelessWidget {
  const _TabBar({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
    required this.addLabel,
    required this.onAdd,
  });

  final List<(IconData, String)> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final String addLabel;
  final VoidCallback onAdd;

  static const _height = 60.0;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return ColoredBox(
      color: colors.background,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: _height,
                  padding: const EdgeInsets.all(6),
                  decoration: ShapeDecoration(
                    color: colors.surface,
                    shape: StadiumBorder(
                      side: BorderSide(color: colors.divider),
                    ),
                  ),
                  child: SlidingSelector(
                    selectedIndex: selectedIndex,
                    gap: 4,
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
                ),
              ),
              const SizedBox(width: 12),
              SizedBox.square(
                dimension: _height,
                child: IconButton.filled(
                  onPressed: onAdd,
                  tooltip: addLabel,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.onAccent,
                  ),
                  icon: const Icon(LucideIcons.plus, size: 28),
                ),
              ),
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
