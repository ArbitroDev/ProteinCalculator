part of 'stats_page.dart';

class _InsightsCard extends StatelessWidget {
  const _InsightsCard({required this.stats, required this.goal});

  final CrossStats stats;

  /// Average goal of the period, coloring the weekdays.
  final double? goal;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = context.localeName;
    String grams(double value) => _grams(value, locale, l10n);
    String percent(double value) => _percent(value, locale);
    String time(int minutes) =>
        formatTime(DateTime(2000, 1, 1, minutes ~/ 60, minutes % 60), locale);
    final slotName = l10n.slotName;

    final sections = <(String, List<Widget>)>[];

    // The goal.
    final goalRows = <Widget>[
      if (stats.shortfall case final shortfall?)
        StatsValueRow(
          label: l10n.statsShortfall,
          value: grams(shortfall.grams),
          detail: l10n.statsShortfallDays(shortfall.days),
        ),
      if (stats.goalTime case final goalTime?)
        StatsValueRow(
          label: l10n.statsGoalTime,
          value: time(goalTime.minutes),
          detail: l10n.statsGoalTimeLate(
            goalTime.late,
            goalTime.days,
            time(lateGoalMinutes),
          ),
        ),
    ];
    if (goalRows.isNotEmpty) sections.add((l10n.statsGoalSection, goalRows));

    if (stats.regularity case final regularity?) {
      String day(int dayKey) => formatShortDate(dateOfDayKey(dayKey), locale);
      sections.add((
        l10n.statsRegularity,
        [
          StatTiles([
            StatTile(
              value: '± ${grams(regularity.deviation)}',
              label: l10n.statsDeviation,
            ),
            StatTile(
              value: grams(regularity.lowest.grams),
              label: l10n.statsLowestDay(day(regularity.lowest.dayKey)),
            ),
            StatTile(
              value: grams(regularity.highest.grams),
              label: l10n.statsHighestDay(day(regularity.highest.dayKey)),
            ),
          ]),
        ],
      ));
    }

    // Protein and workouts.
    final byWorkout = stats.proteinByWorkout;
    final afterDay = stats.proteinAfterWorkoutDay;
    final top = [
      ?byWorkout?.first,
      ?byWorkout?.second,
      ?afterDay,
    ].fold(0.0, (a, b) => a > b ? a : b);
    double fraction(double value) => top <= 0 ? 0 : value / top;
    final workoutRows = <Widget>[
      if (byWorkout != null) ...[
        CompareBar(
          label: l10n.statsOnWorkoutDays,
          value: grams(byWorkout.first),
          fraction: fraction(byWorkout.first),
          color: AppColors.accent,
        ),
        CompareBar(
          label: l10n.statsOnRestDays,
          value: grams(byWorkout.second),
          fraction: fraction(byWorkout.second),
          color: AppColors.progressHalf,
        ),
      ],
      if (afterDay != null)
        CompareBar(
          label: l10n.statsDaysAfterWorkout,
          value: grams(afterDay),
          fraction: fraction(afterDay),
          color: AppColors.progressHalf,
        ),
      if (stats.goalShareByWorkout case final shares?)
        StatsValueRow(
          label: l10n.statsGoalByWorkout,
          value: '${percent(shares.first)} · ${percent(shares.second)}',
        ),
      if (stats.postWorkout case final after?)
        StatsValueRow(
          label: l10n.statsAfterWorkout(postWorkoutWindow.inHours),
          value: grams(after.grams),
          detail: l10n.statsAfterWorkoutFollowed(
            after.followed,
            after.sessions,
            l10n.grams(formatGrams(postWorkoutGrams, locale)),
          ),
        ),
      if (stats.workoutTime case final workoutTime?) ...[
        StatsValueRow(
          label: l10n.statsWorkoutStart,
          value: time(workoutTime.startMinutes),
          detail: [
            for (final MapEntry(key: slot, value: count)
                in workoutTime.counts.entries)
              if (count > 0) l10n.statsSlotCount(slotName(slot), count),
          ].join(' · '),
        ),
        // A comparison needs two parts of the day.
        if (workoutTime.afterGrams.length >= 2) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 2),
            child: Text(
              l10n.statsAfterWorkoutBySlot(postWorkoutWindow.inHours),
              style: Theme.of(context).textTheme.bodyMedium!
                  .copyWith(color: AppColors.of(context).textSecondary),
            ),
          ),
          for (final MapEntry(key: slot, value: after)
              in workoutTime.afterGrams.entries)
            CompareBar(
              label: slotName(slot),
              value: grams(after),
              fraction: () {
                final top = workoutTime.afterGrams.values.max;
                return top <= 0 ? 0.0 : after / top;
              }(),
              color: AppColors.slot(slot),
            ),
        ],
      ],
    ];
    if (workoutRows.isNotEmpty) {
      sections.add((l10n.statsProteinAndWorkouts, workoutRows));
    }

    // Creatine.
    final creatineRows = <Widget>[
      if (stats.creatineByWorkout case final shares?)
        StatsValueRow(
          label: l10n.statsCreatineByWorkout,
          value: '${percent(shares.first)} · ${percent(shares.second)}',
        ),
      if (stats.completeDays case final complete?)
        StatsValueRow(
          label: l10n.statsCompleteDays,
          value: '${complete.days} · ${percent(complete.share)}',
        ),
    ];
    if (creatineRows.isNotEmpty) {
      sections.add((l10n.creatine, creatineRows));
    }

    if (stats.weekdayAverages case final averages?) {
      sections.add((
        l10n.statsWeekdays,
        [_Weekdays(averages: averages, goal: goal)],
      ));
    }

    if (stats.slotShares case final shares?) {
      sections.add((l10n.statsDayParts, [_DayParts(shares: shares)]));
    }

    if (stats.rhythm case final rhythm?) {
      final minutes = rhythm.firstEntryMinutes;
      sections.add((
        l10n.statsRhythm,
        [
          StatTiles([
            StatTile(
              value: NumberFormat(
                '#,##0.0',
                locale,
              ).format(rhythm.entriesPerDay),
              label: l10n.statsEntriesPerDay,
            ),
            StatTile(
              value: grams(rhythm.gramsPerEntry),
              label: l10n.statsPerEntry,
            ),
            StatTile(
              value: formatTime(
                DateTime(2000, 1, 1, minutes ~/ 60, minutes % 60),
                locale,
              ),
              label: l10n.statsFirstEntry,
            ),
          ]),
        ],
      ));
    }

    if (stats.topProducts.isNotEmpty) {
      sections.add((
        l10n.statsTopProducts,
        [
          for (final product in stats.topProducts)
            StatsValueRow(
              label: product.name,
              value: l10n.statsProductUses(
                product.uses,
                l10n.grams(formatGrams(product.grams, locale)),
              ),
            ),
        ],
      ));
    }

    return StatsCard(
      title: l10n.statsInsights,
      children: [
        for (final (index, (title, rows)) in sections.indexed) ...[
          StatsSectionTitle(title, first: index == 0),
          ...rows,
        ],
      ],
    );
  }
}

/// Average protein of each weekday in small bars, with the best and the
/// lowest one.
class _Weekdays extends StatelessWidget {
  const _Weekdays({required this.averages, required this.goal});

  /// From the first day of the week; null for a weekday not counted enough.
  final List<double?> averages;
  final double? goal;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final locale = context.localeName;
    final material = MaterialLocalizations.of(context);
    final firstWeekday = material.firstDayOfWeekIndex;
    final top = averages.nonNulls.max;
    // A date of each weekday, 0 for Sunday, to name it.
    DateTime dateOf(int weekday) => DateTime(2026, 10, 25 + weekday);
    String name(int index) =>
        DateFormat.EEEE(locale).format(dateOf((firstWeekday + index) % 7));

    final indexed = averages.indexed.where((e) => e.$2 != null).toList();
    final best = indexed.reduce((a, b) => b.$2! > a.$2! ? b : a);
    final lowest = indexed.reduce((a, b) => b.$2! < a.$2! ? b : a);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 86,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (index, average) in averages.indexed)
                Expanded(
                  child: Semantics(
                    label: average == null
                        ? name(index)
                        : '${name(index)} · ${_grams(average, locale, l10n)}',
                    excludeSemantics: true,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: average == null
                                  ? null
                                  : FractionallySizedBox(
                                      heightFactor: top <= 0
                                          ? 0
                                          : (average / top).clamp(0.03, 1),
                                      widthFactor: 1,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: progressColor(
                                            average,
                                            goal,
                                            colors,
                                          ),
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                top: Radius.circular(3),
                                              ),
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            material.narrowWeekdays[(firstWeekday + index) % 7],
                            style: textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.statsBestWeekday(name(best.$1), _grams(best.$2!, locale, l10n)),
          style: textTheme.bodyMedium!.copyWith(color: colors.textSecondary),
        ),
        Text(
          l10n.statsLowestWeekday(
            name(lowest.$1),
            _grams(lowest.$2!, locale, l10n),
          ),
          style: textTheme.bodyMedium!.copyWith(color: colors.textSecondary),
        ),
      ],
    );
  }
}

/// Share of the protein of each part of the day, in a stacked bar.
class _DayParts extends StatelessWidget {
  const _DayParts({required this.shares});

  final Map<DaySlot, double> shares;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final locale = context.localeName;
    final name = l10n.slotName;
    final shown = [
      for (final slot in DaySlot.values)
        if ((shares[slot] ?? 0) > 0) slot,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: SizedBox(
              height: 14,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final slot in shown)
                    Expanded(
                      flex: (shares[slot]! * 1000).round().clamp(1, 1000),
                      child: ColoredBox(color: AppColors.slot(slot)),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 14,
          runSpacing: 4,
          children: [
            for (final slot in shown)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: AppColors.slot(slot),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${name(slot)} ${_percent(shares[slot]!, locale)}',
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
