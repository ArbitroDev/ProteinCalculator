import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/domain/app_day.dart';
import 'package:protein_calculator/core/domain/day_slot.dart';
import 'package:protein_calculator/core/formatting.dart';
import 'package:protein_calculator/core/providers.dart';
import 'package:protein_calculator/core/router.dart';
import 'package:protein_calculator/core/theme.dart';
import 'package:protein_calculator/core/widgets/shaker.dart';
import 'package:protein_calculator/l10n/app_localizations.dart';

/// Main tab: the protein total of the current app day, shown in a shaker.
class TodayPage extends ConsumerWidget {
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dayKey = ref.watch(currentDayKeyProvider).value;
    final goal = ref.watch(dailyGoalProvider).value;
    if (dayKey == null || goal == null) return const Scaffold();
    final entries = ref.watch(dayEntriesProvider(dayKey)).value ?? const [];

    final locale = Localizations.localeOf(context).toString();
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatLongDate(dateOfDayKey(dayKey), locale),
                style: textTheme.headlineSmall!.copyWith(fontSize: 28),
              ),
              const SizedBox(height: 4),
              Text(
                AppLocalizations.of(context)
                    .todayGoal(formatGrams(goal, locale)),
                style: textTheme.bodyLarge!.copyWith(
                  fontSize: 17,
                  color: AppColors.of(context).textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _DayGauge(entries: entries, goal: goal, locale: locale),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayGauge extends StatelessWidget {
  const _DayGauge({
    required this.entries,
    required this.goal,
    required this.locale,
  });

  final List<Entry> entries;
  final double goal;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colors = AppColors.of(context);
    String grams(double value) => formatGrams(value, locale);

    final total = entries.fold(0.0, (sum, entry) => sum + entry.proteinGrams);
    final reached = total >= goal;
    final status = textTheme.bodyLarge!.copyWith(
      fontSize: 16,
      color: colors.textSecondary,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final shakerWidth = min(
          constraints.maxHeight * Shaker.aspectRatio,
          constraints.maxWidth * 0.45,
        );
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SizedBox(
              width: shakerWidth,
              child: Shaker(
                layers: [
                  for (final entry in entries)
                    ShakerLayer(
                      grams: entry.proteinGrams,
                      slot: DaySlot.of(entry.createdAt),
                    ),
                ],
                goal: goal,
                semanticLabel: l10n.shakerDescription(
                  grams(total),
                  grams(goal),
                ),
                formatGrams: (value) => l10n.grams(grams(value)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(),
                  ExcludeSemantics(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text.rich(
                        TextSpan(
                          text: grams(total),
                          children: [
                            TextSpan(
                              text: ' ${l10n.gramsUnit}',
                              style: textTheme.displayLarge!.copyWith(
                                fontSize: 28,
                              ),
                            ),
                          ],
                        ),
                        style: textTheme.displayLarge!.copyWith(fontSize: 76),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: l10n.todayEntryCount(entries.length)),
                        const TextSpan(text: ' · '),
                        if (reached) ...[
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Icon(
                              LucideIcons.circleCheck,
                              size: 16,
                              color: colors.accentText,
                            ),
                          ),
                          const TextSpan(text: ' '),
                          TextSpan(
                            text: l10n.todayGoalReached,
                            style: status.copyWith(
                              color: colors.accentText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ] else
                          TextSpan(
                            text: l10n.todayRemaining(grams(goal - total)),
                          ),
                      ],
                    ),
                    style: status,
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: () => context.push(AppRoutes.newEntry),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 52),
                      textStyle: textTheme.labelLarge!.copyWith(fontSize: 16),
                    ),
                    icon: const Icon(LucideIcons.plus, size: 20),
                    label: Text(l10n.addEntry),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
