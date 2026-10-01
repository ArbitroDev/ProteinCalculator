import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:protein_calculator/core/theme.dart';
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
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<(IconData, String)> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelStyle = Theme.of(context).textTheme.labelSmall!;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? colors.background : colors.surface,
        border: Border(top: BorderSide(color: colors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
          child: Row(
            children: [
              for (final (index, (icon, label)) in tabs.indexed)
                Expanded(
                  child: _Tab(
                    icon: icon,
                    label: label,
                    selected: index == selectedIndex,
                    labelStyle: labelStyle,
                    onTap: () => onSelected(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.labelStyle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final TextStyle labelStyle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? AppColors.onAccent
        : AppColors.of(context).textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: selected ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          child: InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 20, color: color),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: labelStyle.copyWith(
                      color: color,
                      fontWeight: selected ? FontWeight.w600 : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
