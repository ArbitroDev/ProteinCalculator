import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:protein_calculator/core/database/entries_dao.dart';
import 'package:protein_calculator/core/domain/app_day.dart';
import 'package:protein_calculator/core/domain/day_progress.dart';
import 'package:protein_calculator/core/domain/history_view.dart';
import 'package:protein_calculator/core/formatting.dart';
import 'package:protein_calculator/core/providers.dart';
import 'package:protein_calculator/core/router.dart';
import 'package:protein_calculator/core/theme.dart';
import 'package:protein_calculator/core/widgets/content_width.dart';
import 'package:protein_calculator/core/widgets/empty_state.dart';
import 'package:protein_calculator/core/widgets/locale_name.dart';
import 'package:protein_calculator/core/widgets/pill_tabs.dart';
import 'package:protein_calculator/core/widgets/stacked_bar.dart';
import 'package:protein_calculator/core/widgets/user_action.dart';
import 'package:protein_calculator/features/history/calendar_view.dart';
import 'package:protein_calculator/l10n/app_localizations.dart';

/// History tab: every day with entries, most recent first, or a calendar
/// of the days. The view chosen is remembered, the list by default.
class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final view = ref.watch(historyViewProvider).value ?? HistoryView.list;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabHistory)),
      body: ContentWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
              child: PillTabs(
                labels: {
                  HistoryView.list: l10n.historyList,
                  HistoryView.calendar: l10n.historyCalendar,
                },
                selected: view,
                onChanged: (value) => runUserAction(
                  ScaffoldMessenger.of(context),
                  l10n,
                  () => ref
                      .read(databaseProvider)
                      .settingsDao
                      .setHistoryView(value),
                ),
              ),
            ),
            Expanded(
              child: switch (view) {
                HistoryView.list => const _DayList(),
                HistoryView.calendar => const CalendarView(),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DayList extends ConsumerWidget {
  const _DayList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(historyProvider).value;
    final goals = ref.watch(goalChangesProvider).value ?? const [];
    final goal = ref.watch(dailyGoalProvider).value;

    return switch (days) {
      null => const SizedBox.shrink(),
      [] => EmptyState(AppLocalizations.of(context).historyEmpty),
      _ => ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        itemCount: days.length,
        itemBuilder: (context, index) => _DayTile(
          day: days[index],
          // The goal each day had.
          goal: goalOn(days[index].dayKey, goals) ?? goal ?? 0,
        ),
      ),
    };
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
    final locale = context.localeName;
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
