part of '../share_tiles.dart';

/// A week or a month of statistics: the daily average, a bar per day and
/// the days at the goal.
class PeriodTile extends StatelessWidget {
  const PeriodTile({super.key, required this.stats, required this.today});

  final PeriodStats stats;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = context.localeName;
    final protein = stats.protein;
    final delta = protein.deltaGrams;
    String? compared;
    if (delta != null) {
      final sign = delta > 0
          ? '+'
          : delta < 0
          ? '−'
          : '±';
      final text =
          '$sign${l10n.grams(NumberFormat.decimalPattern(locale).format(delta.abs()))}';
      compared = stats.period.span == StatsSpan.week
          ? l10n.statsComparedToPreviousWeek(text)
          : l10n.statsComparedTo(
              text,
              DateFormat.MMMM(locale).format(stats.period.previous.start),
            );
    }
    final week = stats.period.span == StatsSpan.week;

    return ShareTileFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            sharePeriodName(stats.period, l10n, locale, today),
            style: _body(14.5),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // A large average shrinks rather than crowd out its label.
              Flexible(
                flex: 3,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.bottomLeft,
                  child: _Grams(protein.averageGrams, size: 70),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    l10n.statsDailyAverage,
                    style: _body(13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          // Long in French: on a line of its own, the whole width.
          if (compared != null) ...[
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(compared, style: _body(13), maxLines: 1),
            ),
          ],
          const SizedBox(height: 14),
          Expanded(
            child: _TileBars(
              values: [for (final bar in protein.bars) bar.grams],
              goals: [for (final bar in protein.bars) bar.goal],
              goal: protein.averageGoal?.roundToDouble(),
              gap: week ? 8 : 2.5,
              labels: week
                  ? [
                      for (final bar in protein.bars)
                        DateFormat.E(locale).format(bar.date),
                    ]
                  : null,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Stat(
                value: '${protein.goalDays} / ${protein.countedDays}',
                label: l10n.shareGoalDays,
              ),
              const SizedBox(width: 28),
              _Stat(
                value: l10n.statsDayCount(protein.bestStreak),
                label: l10n.statsBestStreak,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A year: the days at the goal, the average of each month and the
/// workouts.
class YearTile extends StatelessWidget {
  const YearTile({super.key, required this.stats});

  final PeriodStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = context.localeName;
    final protein = stats.protein;
    final workouts = stats.workouts;

    return ShareTileFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.shareYear(stats.period.start.year), style: _body(14.5)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                NumberFormat.decimalPattern(locale).format(protein.goalDays),
                style: _display(70),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    l10n.shareYearGoalDays(
                      protein.goalDays,
                      protein.countedDays,
                    ),
                    style: _body(13),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _TileBars(
              values: [for (final bar in protein.bars) bar.grams],
              goals: [for (final bar in protein.bars) bar.goal],
              goal: protein.averageGoal?.roundToDouble(),
              gap: 5,
              labels: [
                for (final bar in protein.bars)
                  DateFormat('MMMMM', locale).format(bar.date),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Stat(
                value: l10n.grams(formatGrams(protein.averageGrams, locale)),
                label: l10n.statsDailyAverage,
              ),
              const SizedBox(width: 28),
              if (workouts != null && workouts.sessions > 0)
                _Stat(
                  value: '${workouts.sessions}',
                  label: l10n.shareHevyWorkouts(workouts.sessions),
                )
              else
                _Stat(
                  value: l10n.statsDayCount(protein.bestStreak),
                  label: l10n.statsBestStreak,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Most shakers drawn on the streak tile.
const streakMaxShakers = 30;

/// The current streak: one number, one shaker per day.
class StreakTile extends StatelessWidget {
  const StreakTile({super.key, required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = context.localeName;
    const ink = AppColors.onAccent;
    final drawn = min(streak, streakMaxShakers);

    return ShareTileFrame(
      orange: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.shareCurrentStreak,
            style: _body(14.5, color: shareOnOrangeSecondary),
          ),
          // The number takes the room the shakers leave.
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                NumberFormat.decimalPattern(locale).format(streak),
                style: _display(170, color: ink),
              ),
            ),
          ),
          Text(
            l10n.shareStreakDays(streak),
            style: _display(26, color: ink, weight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          IconTheme(
            data: const IconThemeData(color: ink, size: 24),
            child: Wrap(
              spacing: 3,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (var i = 0; i < drawn; i++) const ShakerIcon(),
                if (streak > drawn)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      '+${streak - drawn}',
                      style: _body(13, color: ink, weight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The creatine of a period: how regularly it was taken, as a ring, with
/// its streak and doses, and its days in a thin strip.
class CreatineTile extends StatelessWidget {
  const CreatineTile({super.key, required this.stats, required this.today});

  final PeriodStats stats;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = context.localeName;
    final creatine = stats.creatine!;
    final streak = creatine.currentStreak;
    final share = creatine.countedDays == 0
        ? 0.0
        : creatine.takenDays / creatine.countedDays;
    final complete = stats.cross.completeDays;

    return ShareTileFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PeriodKicker(
            title: l10n.creatine,
            period: stats.period,
            today: today,
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Row(
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: CustomPaint(
                    painter: _Ring(
                      share: share,
                      color: AppColors.creatine,
                      track: _colors.surface,
                    ),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Padding(
                          padding: const EdgeInsets.all(26),
                          child: Text(
                            NumberFormat.percentPattern(locale).format(share),
                            style: _display(44),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 22),
                Expanded(
                  // Long words shrink the column rather than overflow it,
                  // its width kept.
                  child: LayoutBuilder(
                    builder: (context, constraints) => FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: constraints.maxWidth,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '${creatine.takenDays} / ${creatine.countedDays}',
                                style: _display(34, weight: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.shareCreatineDaysLabel(creatine.takenDays),
                              style: _body(12.5),
                            ),
                            const SizedBox(height: 12),
                            _Stat(
                              value: '${creatine.doses}',
                              label: l10n.statsDosesLabel(creatine.doses),
                              flexible: false,
                            ),
                            if (streak != null && streak > 0) ...[
                              const SizedBox(height: 10),
                              _Stat(
                                value: l10n.statsDayCount(streak),
                                label: l10n.statsCurrentStreak,
                                flexible: false,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (complete != null) ...[
            const SizedBox(height: 14),
            _TileRow(label: l10n.statsCompleteDays, value: '${complete.days}'),
          ],
          const SizedBox(height: 12),
          _MarksStrip(
            marks: creatine.marks,
            monthShares: creatine.monthShares,
            color: AppColors.creatine,
          ),
        ],
      ),
    );
  }
}

/// The Hevy workouts of a period: their number and length, then the
/// protein of the workout days against the rest days, and after a workout.
class WorkoutTile extends StatelessWidget {
  const WorkoutTile({super.key, required this.stats, required this.today});

  final PeriodStats stats;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = context.localeName;
    final workouts = stats.workouts!;
    final week = stats.period.span == StatsSpan.week;
    final average = workouts.averageDuration;
    final cross = stats.cross;
    final byWorkout = cross.proteinByWorkout;
    final after = cross.postWorkout;
    String grams(double value) => l10n.grams(formatGrams(value, locale));
    final top = max(byWorkout?.first ?? 0, byWorkout?.second ?? 0);

    return ShareTileFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PeriodKicker(
            title: l10n.statsWorkouts,
            period: stats.period,
            today: today,
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                NumberFormat.decimalPattern(locale).format(workouts.sessions),
                style: _display(70),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    [
                      l10n.shareHevyWorkouts(workouts.sessions),
                      if (week)
                        l10n.statsWorkoutDays(workouts.days)
                      else
                        '${NumberFormat('#,##0.0', locale).format(workouts.perWeek)} ${l10n.statsPerWeek}',
                      if (average != null)
                        '${formatDuration(average, l10n)} · ${l10n.statsAverageLength}',
                    ].join('\n'),
                    style: _body(12.5),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          if (cross.workoutTime case final workoutTime?) ...[
            _TileRow(
              label: l10n.statsWorkoutStart,
              value: formatTime(
                DateTime(
                  2000,
                  1,
                  1,
                  workoutTime.startMinutes ~/ 60,
                  workoutTime.startMinutes % 60,
                ),
                locale,
              ),
            ),
            const Spacer(),
          ],
          if (byWorkout != null) ...[
            Text(
              l10n.formProtein,
              style: _body(12.5, color: _colors.text, weight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            _TileCompareBar(
              label: l10n.statsOnWorkoutDays,
              value: grams(byWorkout.first),
              fraction: top <= 0 ? 0 : byWorkout.first / top,
              color: AppColors.accent,
            ),
            const SizedBox(height: 8),
            _TileCompareBar(
              label: l10n.statsOnRestDays,
              value: grams(byWorkout.second),
              fraction: top <= 0 ? 0 : byWorkout.second / top,
              color: AppColors.progressHalf,
            ),
          ],
          if (after != null) ...[
            const SizedBox(height: 12),
            _TileRow(
              label: l10n.statsAfterWorkout(postWorkoutWindow.inHours),
              value: grams(after.grams),
            ),
          ],
          const Spacer(),
          _MarksStrip(
            marks: workouts.marks,
            monthShares: workouts.monthShares,
            color: _colors.hevy,
          ),
        ],
      ),
    );
  }
}
