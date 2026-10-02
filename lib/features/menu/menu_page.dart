import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:protein_calculator/core/domain/grams.dart';
import 'package:protein_calculator/core/formatting.dart';
import 'package:protein_calculator/core/providers.dart';
import 'package:protein_calculator/core/router.dart';
import 'package:protein_calculator/core/theme.dart';
import 'package:protein_calculator/core/widgets/goal_field.dart';
import 'package:protein_calculator/l10n/app_localizations.dart';

/// Menu tab: daily goal, privacy, licenses and about.
class MenuPage extends ConsumerWidget {
  const MenuPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toString();
    final goal = ref.watch(dailyGoalProvider).value;
    final version = ref.watch(appVersionProvider).value;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabMenu)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
        children: [
          Material(
            color: colors.surface,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: goal == null ? null : () => _editGoal(context, goal),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.menuGoal, style: textTheme.bodySmall),
                          Text(
                            goal == null
                                ? ''
                                : l10n.grams(formatGrams(goal, locale)),
                            style: textTheme.displaySmall!.copyWith(
                              fontSize: 36,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      l10n.edit,
                      style: textTheme.bodyLarge!.copyWith(
                        color: colors.accentText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _MenuItem(
            icon: LucideIcons.shieldCheck,
            label: l10n.menuPrivacy,
            onTap: () => context.go(AppRoutes.dataPrivacy),
          ),
          _MenuItem(
            icon: LucideIcons.fileText,
            label: l10n.menuLicenses,
            onTap: () => showLicensePage(
              context: context,
              applicationName: l10n.appTitle,
              applicationVersion: version,
              applicationLegalese: l10n.licensesExplanation,
            ),
          ),
          _MenuItem(
            icon: LucideIcons.info,
            label: l10n.menuAbout,
            onTap: () => context.go(AppRoutes.about),
          ),
        ],
      ),
    );
  }

  Future<void> _editGoal(BuildContext context, double goal) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: AppColors.of(context).background,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        builder: (context) => _GoalSheet(goal: goal),
      );
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.divider)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: colors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyLarge!
                    .copyWith(fontSize: 16),
              ),
            ),
            Icon(
              LucideIcons.chevronRight,
              size: 18,
              color: colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet editing the daily goal.
class _GoalSheet extends ConsumerStatefulWidget {
  const _GoalSheet({required this.goal});

  final double goal;

  @override
  ConsumerState<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends ConsumerState<_GoalSheet> {
  late final _controller = TextEditingController(
    text: widget.goal.round().toString(),
  );
  bool _showError = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final goal = parseDailyGoal(_controller.text);
    if (goal == null) {
      setState(() => _showError = true);
      return;
    }
    await ref.read(databaseProvider).settingsDao.setDailyGoal(goal);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        22,
        22,
        22,
        18 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.menuGoal, style: textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            l10n.goalSheetBody,
            style: textTheme.bodyLarge!.copyWith(
              color: AppColors.of(context).textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          GoalField(
            controller: _controller,
            autofocus: true,
            showError: _showError,
            onChanged: (_) => setState(() => _showError = false),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }
}
