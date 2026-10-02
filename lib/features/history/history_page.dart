import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:protein_calculator/core/database/entries_dao.dart';
import 'package:protein_calculator/core/domain/app_day.dart';
import 'package:protein_calculator/core/formatting.dart';
import 'package:protein_calculator/core/providers.dart';
import 'package:protein_calculator/core/router.dart';
import 'package:protein_calculator/core/theme.dart';
import 'package:protein_calculator/core/widgets/stacked_bar.dart';
import 'package:protein_calculator/core/widgets/content_width.dart';
import 'package:protein_calculator/l10n/app_localizations.dart';

/// History tab: every day with entries, most recent first.
class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final days = ref.watch(historyProvider).value;
    final goal = ref.watch(dailyGoalProvider).value ?? 0;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabHistory)),
      body: ContentWidth(
        child: switch (days) {
          null => const SizedBox.shrink(),
          [] => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                l10n.historyEmpty,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge!
                    .copyWith(color: AppColors.of(context).textSecondary),
              ),
            ),
          ),
          _ => ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            itemCount: days.length,
            itemBuilder: (context, index) =>
                _DayTile(day: days[index], goal: goal),
          ),
        },
      ),
    );
  }
}

class _DayTile extends StatelessWidget {
  const _DayTile({required this.day, required this.goal});

  final DaySummary day;
  final double goal;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toString();
    final total = day.proteinGrams;
    final reached = goal > 0 && total >= goal;

    return InkWell(
      onTap: () => context.go(AppRoutes.historyDay(day.dayKey)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.divider)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    formatShortDate(dateOfDayKey(day.dayKey), locale),
                    style: textTheme.titleMedium,
                  ),
                ),
                if (reached) ...[
                  Icon(
                    LucideIcons.circleCheck,
                    size: 16,
                    color: colors.accentText,
                  ),
                  const SizedBox(width: 5),
                ],
                Text(
                  l10n.grams(formatGrams(total, locale)),
                  style: textTheme.titleMedium!.copyWith(
                    fontWeight: FontWeight.w700,
                    color: reached ? colors.accentText : colors.text,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            StackedBar(bySlot: day.bySlot, goal: goal, height: 7),
          ],
        ),
      ),
    );
  }
}
