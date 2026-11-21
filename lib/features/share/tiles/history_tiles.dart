part of '../share_tiles.dart';

/// A month of the calendar as its tile shows it.
@immutable
class MonthShare {
  const MonthShare({
    required this.month,
    required this.grams,
    required this.goalOf,
    required this.todayKey,
    required this.firstAppDayKey,
    required this.firstWeekday,
    this.creatineDays = const {},
    this.hevyDays = const {},
    this.mode = CalendarMode.protein,
  });

  /// First day of the month.
  final DateTime month;

  /// Protein grams of the days with entries, by key.
  final Map<int, double> grams;
  final double? Function(int dayKey) goalOf;
  final int todayKey;
  final int firstAppDayKey;

  /// First day of the week, 0 for Sunday.
  final int firstWeekday;

  /// Days creatine was taken.
  final Set<int> creatineDays;

  /// Days with a Hevy workout.
  final Set<int> hevyDays;

  /// What colors the days, as in the calendar.
  final CalendarMode mode;
}

/// A month of the calendar, each day colored as the calendar colors it: by
/// its progress, by the creatine taken or by the Hevy workouts.
class CalendarMonthTile extends StatelessWidget {
  const CalendarMonthTile({super.key, required this.data});

  final MonthShare data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = context.localeName;
    final material = MaterialLocalizations.of(context);
    final month = data.month;
    final mode = data.mode;
    final days = DateTime(month.year, month.month + 1, 0).day;
    final lead = (month.weekday % 7 - data.firstWeekday + 7) % 7;
    var marked = 0;
    final cells = <Widget>[
      for (var i = 0; i < lead; i++) const SizedBox.shrink(),
    ];
    for (var day = 1; day <= days; day++) {
      final dayKey = dayKeyOfDate(DateTime(month.year, month.month, day));
      final goal = data.goalOf(dayKey);
      // As in the calendar: the days from the first one of the app to
      // today, those without entries as days of 0 g.
      final tracked =
          goal != null &&
          dayKey >= data.firstAppDayKey &&
          dayKey <= data.todayKey;
      final progress = tracked
          ? DayProgress.of(data.grams[dayKey] ?? 0, goal)
          : null;
      final creatine = data.creatineDays.contains(dayKey);
      final hevy = data.hevyDays.contains(dayKey);
      final highlighted = switch (mode) {
        CalendarMode.protein => progress == DayProgress.reached,
        CalendarMode.creatine => progress != null && creatine,
        CalendarMode.hevy => progress != null && hevy,
      };
      if (highlighted) marked++;
      // As in the calendar: days to come lighter.
      final style = progress == null
          ? (
              fill: Colors.transparent,
              text: _colors.textSecondary.withValues(
                alpha: dayKey > data.todayKey ? 0.5 : 1,
              ),
            )
          : switch (mode) {
              CalendarMode.protein => calendarProgressColors(progress, _colors),
              CalendarMode.creatine => calendarCreatineColors(
                creatine,
                _colors,
              ),
              CalendarMode.hevy => calendarHevyColors(hevy, _colors),
            };
      final isToday = dayKey == data.todayKey;
      cells.add(
        Center(
          child: AspectRatio(
            aspectRatio: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: style.fill,
                shape: BoxShape.circle,
                border: isToday
                    ? Border.all(color: _colors.structure, width: 2)
                    : null,
              ),
              child: Center(
                child: Text(
                  '$day',
                  style: _body(
                    12.5,
                    color: style.text,
                    weight: highlighted || isToday
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ).copyWith(height: 1),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final none = calendarProgressColors(DayProgress.none, _colors);
    final legend = switch (mode) {
      CalendarMode.protein => [
        for (final progress in DayProgress.values)
          _LegendItem(
            label: calendarProgressLabel(l10n, progress),
            fill: calendarProgressColors(progress, _colors).fill,
            bordered: progress == DayProgress.none,
          ),
      ],
      CalendarMode.creatine => [
        _LegendItem(label: l10n.calendarNone, fill: none.fill, bordered: true),
        _LegendItem(
          label: l10n.calendarCreatine,
          fill: calendarCreatineColors(true, _colors).fill,
        ),
      ],
      CalendarMode.hevy => [
        _LegendItem(
          label: l10n.calendarNoHevy,
          fill: none.fill,
          bordered: true,
        ),
        _LegendItem(
          label: l10n.calendarHevy,
          fill: calendarHevyColors(true, _colors).fill,
        ),
      ],
    };

    return ShareTileFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    toBeginningOfSentenceCase(
                      DateFormat.MMMM(locale).format(month),
                    ),
                    style: _display(38),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(switch (mode) {
                CalendarMode.protein => l10n.shareMonthReached(marked),
                CalendarMode.creatine => l10n.shareMonthCreatine(marked),
                CalendarMode.hevy => l10n.shareMonthHevy(marked),
              }, style: _body(13.5)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Text(
                    material.narrowWeekdays[(data.firstWeekday + i) % 7],
                    textAlign: TextAlign.center,
                    style: _body(11, weight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final rows = ((lead + days) / 7).ceil();
                const gap = 4.0;
                final width = (constraints.maxWidth - gap * 6) / 7;
                final height =
                    (constraints.maxHeight - gap * (rows - 1)) / rows;
                return GridView.count(
                  crossAxisCount: 7,
                  mainAxisSpacing: gap,
                  crossAxisSpacing: gap,
                  childAspectRatio: width / height,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  children: cells,
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          // Two by two, as in the calendar.
          for (final (index, row) in legend.slices(2).indexed) ...[
            if (index > 0) const SizedBox(height: 4),
            Row(
              children: [
                for (final item in row) Expanded(child: item),
                if (row.length == 1) const Spacer(),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// A color of the calendar tile and what it tells.
class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.label,
    required this.fill,
    this.bordered = false,
  });

  final String label;
  final Color fill;
  final bool bordered;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 11,
        height: 11,
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
          border: bordered ? Border.all(color: _colors.divider) : null,
        ),
      ),
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _body(11.5),
        ),
      ),
    ],
  );
}

/// A day of the week tile: its protein by part of the day, its goal, and
/// whether creatine was taken and a Hevy workout done.
typedef WeekDayShare = ({
  int dayKey,
  Map<DaySlot, double> bySlot,
  double goal,
  bool creatine,
  bool hevy,
});

/// The last 7 days, each as a shaker filled to its level.
class WeekTile extends StatelessWidget {
  const WeekTile({super.key, required this.days, required this.today});

  /// Oldest first.
  final List<WeekDayShare> days;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = context.localeName;
    double total(WeekDayShare day) => day.bySlot.values.sum;
    final reached = days
        .where((day) => day.goal > 0 && isGoalReached(total(day), day.goal))
        .length;
    final first = dateOfDayKey(days.first.dayKey);
    final last = dateOfDayKey(days.last.dayKey);
    final marked = days.any((day) => day.creatine || day.hevy);

    return ShareTileFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.shareMyWeek, style: _display(38)),
          const SizedBox(height: 6),
          Text(
            l10n.shareWeekRange(
              formatDayMonth(first, locale, now: today),
              formatDayMonth(last, locale, now: today),
              reached,
              days.length,
            ),
            style: _body(13.5),
          ),
          // The shakers shrink to the room the title leaves them.
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SizedBox(
                    width: constraints.maxWidth,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final day in days)
                          Expanded(
                            child: Column(
                              children: [
                                SizedBox(
                                  height: 118,
                                  width: 118 * Shaker.aspectRatio,
                                  child: Shaker(
                                    layers: [
                                      for (final slot in DaySlot.values)
                                        if ((day.bySlot[slot] ?? 0) > 0)
                                          ShakerLayer(
                                            grams: day.bySlot[slot]!,
                                            slot: slot,
                                          ),
                                    ],
                                    goal: day.goal,
                                    showGoalLine: false,
                                    semanticLabel: l10n.shakerDescription(
                                      formatGrams(total(day), locale),
                                      formatGrams(day.goal, locale),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  NumberFormat.decimalPattern(locale)
                                      .format(roundGrams(total(day))),
                                  style: _display(18, weight: FontWeight.w700),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  DateFormat.E(locale)
                                      .format(dateOfDayKey(day.dayKey)),
                                  style: _body(11, weight: FontWeight.w600),
                                ),
                                // The marks of the calendar, the same height for all.
                                if (marked) ...[
                                  const SizedBox(height: 5),
                                  SizedBox(
                                    height: 12,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      spacing: 2,
                                      children: [
                                        if (day.creatine)
                                          const CreatineCheck(size: 12),
                                        if (day.hevy) const HevyMark(size: 12),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
