part of 'stats_page.dart';

/// Grams rounded to the unit, as everywhere: "136 g".
String _grams(double grams, String locale, AppLocalizations l10n) =>
    l10n.grams(formatGrams(grams, locale));

String _percent(double share, String locale) =>
    NumberFormat.percentPattern(locale).format(share);

/// [count] of [total], as tiles show them: "17 / 25".
String _outOf(int count, int total) => '$count / $total';

class _ProteinCard extends StatelessWidget {
  const _ProteinCard({
    required this.stats,
    required this.goal,
    required this.canOpen,
  });

  final PeriodStats stats;

  /// Current goal, for a period without goal of its own.
  final double? goal;
  final bool Function(int dayKey) canOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final locale = context.localeName;
    final protein = stats.protein;
    final period = stats.period;
    final unitStyle = textTheme.headlineSmall!.copyWith(
      fontSize: 22,
      fontWeight: FontWeight.w600,
    );

    final delta = protein.deltaGrams;
    String? compared;
    String? deltaText;
    if (delta != null) {
      final sign = delta > 0
          ? '+'
          : delta < 0
          ? '−'
          : '±';
      deltaText =
          '$sign${l10n.grams(NumberFormat.decimalPattern(locale).format(delta.abs()))}';
      final previous = period.previous.start;
      compared = switch (period.span) {
        StatsSpan.week => l10n.statsComparedToPreviousWeek(deltaText),
        StatsSpan.month => l10n.statsComparedTo(
          deltaText,
          DateFormat.MMMM(locale).format(previous),
        ),
        StatsSpan.year => l10n.statsComparedTo(deltaText, '${previous.year}'),
      };
    }

    String describe(StatsBar bar) {
      final when = bar.dayKey == null
          ? formatMonth(bar.date, locale)
          : formatShortDate(bar.date, locale);
      return '$when · ${_grams(bar.grams ?? 0, locale, l10n)}';
    }

    final averageGoal = protein.averageGoal;
    final chartGoal = averageGoal?.roundToDouble() ?? goal;
    return StatsCard(
      title: l10n.statsProtein,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: NumberFormat.decimalPattern(locale)
                    .format(roundGrams(protein.averageGrams)),
                style: textTheme.displayMedium,
              ),
              TextSpan(text: ' ${l10n.gramsUnit}', style: unitStyle),
              if (averageGoal != null)
                TextSpan(
                  text: '  / ${_grams(averageGoal, locale, l10n)}',
                  style: unitStyle.copyWith(color: colors.textSecondary),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text.rich(
          TextSpan(
            style: textTheme.bodyMedium!.copyWith(color: colors.textSecondary),
            children: [
              TextSpan(text: l10n.statsDailyAverage),
              if (compared != null && deltaText != null) ...[
                const TextSpan(text: ' · '),
                ..._highlighted(
                  compared,
                  deltaText,
                  TextStyle(
                    color: colors.accentText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        StatTiles([
          StatTile(
            value: _outOf(protein.goalDays, protein.countedDays),
            label: l10n.statsGoalReached(
              _percent(protein.goalDays / protein.countedDays, locale),
            ),
          ),
          if (protein.currentStreak case final streak?)
            StatTile(
              value: l10n.statsDayCount(streak),
              label: l10n.statsCurrentStreak,
            ),
          StatTile(
            value: l10n.statsDayCount(protein.bestStreak),
            label: l10n.statsBestStreak,
          ),
        ]),
        const SizedBox(height: 10),
        StatsBarChart(
          bars: protein.bars,
          span: period.span,
          // The goal of the days of the period, coloring their bars, rather
          // than the current one, which may have changed since.
          goal: chartGoal,
          goalLabel: l10n.grams(formatGrams(chartGoal ?? 0, locale)),
          describe: describe,
          canOpen: (bar) => bar.dayKey != null && canOpen(bar.dayKey!),
          onOpen: (bar) => context.go(AppRoutes.historyDay(bar.dayKey!)),
        ),
      ],
    );
  }
}

/// [text] in spans, [part] of it in [style].
List<TextSpan> _highlighted(String text, String part, TextStyle style) {
  final index = text.indexOf(part);
  if (index < 0) return [TextSpan(text: text)];
  return [
    TextSpan(text: text.substring(0, index)),
    TextSpan(text: part, style: style),
    TextSpan(text: text.substring(index + part.length)),
  ];
}

class _CreatineCard extends StatelessWidget {
  const _CreatineCard({required this.stats, required this.period});

  final CreatineStats stats;
  final StatsPeriod period;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final locale = context.localeName;
    return StatsCard(
      title: l10n.creatine,
      titleColor: colors.creatineText,
      children: [
        if (stats.countedDays == 0)
          Text(
            l10n.statsNoCreatine,
            style: Theme.of(context).textTheme.bodyMedium!
                .copyWith(color: colors.textSecondary),
          )
        else ...[
          StatTiles([
            StatTile(
              value: _outOf(stats.takenDays, stats.countedDays),
              label: l10n.statsCreatineDays(
                _percent(stats.takenDays / stats.countedDays, locale),
              ),
            ),
            if (stats.currentStreak case final streak?)
              StatTile(
                value: l10n.statsDayCount(streak),
                label: l10n.statsCurrentStreak,
              ),
            StatTile(
              value: '${stats.doses}',
              label: l10n.statsDosesLabel(stats.doses),
            ),
          ]),
          DayMarksStrip(
            marks: stats.marks,
            monthShares: stats.monthShares,
            color: AppColors.creatine,
            summary: l10n.statsMarks(stats.takenDays, stats.countedDays),
          ),
        ],
      ],
    );
  }
}

class _WorkoutsCard extends StatelessWidget {
  const _WorkoutsCard({required this.stats, required this.period});

  final WorkoutStats stats;
  final StatsPeriod period;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final locale = context.localeName;
    final week = period.span == StatsSpan.week;
    final total = stats.totalDuration;
    final average = stats.averageDuration;
    final counted = stats.marks.isNotEmpty ? stats.marks.nonNulls.length : null;

    return StatsCard(
      title: l10n.statsWorkouts,
      caption: 'Hevy',
      children: [
        if (stats.sessions == 0)
          Text(
            l10n.statsNoWorkout,
            style: textTheme.bodyMedium!.copyWith(color: colors.textSecondary),
          )
        else ...[
          StatTiles([
            StatTile(
              value: '${stats.sessions}',
              label: l10n.statsSessionsLabel(stats.sessions),
            ),
            if (week)
              StatTile(
                value: '${stats.days}',
                label: l10n.statsWorkoutDaysLabel(stats.days),
              )
            else
              StatTile(
                value: NumberFormat('#,##0.0', locale).format(stats.perWeek),
                label: l10n.statsPerWeek,
              ),
            StatTile(
              value: average == null ? '—' : formatDuration(average, l10n),
              label: l10n.statsAverageLength,
            ),
          ]),
          const SizedBox(height: 8),
          Text(
            [
              if (!week) l10n.statsWorkoutDays(stats.days),
              if (total != null)
                l10n.statsTotalLength(formatDuration(total, l10n)),
            ].join(' · '),
            style: textTheme.bodyMedium!.copyWith(color: colors.textSecondary),
          ),
          DayMarksStrip(
            marks: stats.marks,
            monthShares: stats.monthShares,
            color: colors.hevy,
            summary: counted == null
                ? l10n.statsWorkoutDays(stats.days)
                : l10n.statsMarks(stats.days, counted),
          ),
        ],
      ],
    );
  }
}
