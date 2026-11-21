part of '../share_tiles.dart';

/// The shaker of a day, filled as it is, with the total and the goal.
class DayShakerTile extends StatelessWidget {
  const DayShakerTile({super.key, required this.day});

  final DayShare day;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = context.localeName;
    final total = day.total;
    final goal = day.goal;
    final percent = goalPercent(total, goal);
    final chips = _dayChips(day, context);

    return ShareTileFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatLongDate(dateOfDayKey(day.dayKey), locale),
              style: _display(26, weight: FontWeight.w700),
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  height: 226,
                  width: 226 * Shaker.aspectRatio,
                  child: Shaker(
                    layers: day.layers,
                    goal: goal,
                    creatineDoses: day.creatineDoses,
                    semanticLabel: l10n.shakerDescription(
                      formatGrams(total, locale),
                      formatGrams(goal, locale),
                    ),
                  ),
                ),
                const SizedBox(width: 22),
                Expanded(
                  // A full day may be taller than the shaker: it then shrinks to
                  // fit, its width kept.
                  child: LayoutBuilder(
                    builder: (context, constraints) => FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: constraints.maxWidth,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: _Grams(total, size: 88),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n.shareOfGoal(
                                formatGrams(goal, locale),
                                percent,
                              ),
                              style: _body(14.5),
                            ),
                            if (day.reached) ...[
                              if (gramsOver(total, goal) > 0)
                                Text(
                                  l10n.shareOverGoal(
                                    formatGrams(
                                      gramsOver(total, goal).toDouble(),
                                      locale,
                                    ),
                                  ),
                                  style: _body(14.5),
                                ),
                              const SizedBox(height: 10),
                              _Chip(
                                label: l10n.shareGoalReached,
                                background: AppColors.accent,
                                foreground: AppColors.onAccent,
                              ),
                              if (day.streak >= 3) ...[
                                const SizedBox(height: 8),
                                Text(
                                  l10n.shareStreak(day.streak),
                                  style: _body(14.5),
                                ),
                              ],
                            ] else if (day.isToday)
                              Text(
                                l10n.todayRemaining(
                                  formatGrams(
                                    gramsLeft(total, goal).toDouble(),
                                    locale,
                                  ),
                                ),
                                style: _body(14.5),
                              )
                            else
                              Text(
                                l10n.shareShort(
                                  formatGrams(
                                    gramsLeft(total, goal).toDouble(),
                                    locale,
                                  ),
                                ),
                                style: _body(14.5),
                              ),
                            if (chips.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Wrap(spacing: 6, runSpacing: 6, children: chips),
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
        ],
      ),
    );
  }
}

/// Most entries listed on the timeline of a day.
const timelineMaxEntries = 6;

/// The entries of a day hour by hour, then the share of each part of the
/// day.
class DayTimelineTile extends StatelessWidget {
  const DayTimelineTile({
    super.key,
    required this.day,
    required this.showProducts,
  });

  final DayShare day;

  /// Whether the names of the products show.
  final bool showProducts;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = context.localeName;
    final protein = [
      for (final entry in day.entries)
        if (entry.proteinGrams > 0) entry,
    ];
    final most = protein.map((e) => e.proteinGrams).maxOrNull ?? 1;
    final reachedAt = day.reachedAt;
    final goal = formatGrams(day.goal, locale);

    final bySlot = {for (final slot in DaySlot.values) slot: 0.0};
    for (final entry in protein) {
      bySlot[entry.slot] = bySlot[entry.slot]! + entry.proteinGrams;
    }
    final total = day.total;
    final slotName = l10n.slotName;

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
                  child: _Grams(total, size: 60),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                formatShortDate(dateOfDayKey(day.dayKey), locale),
                style: _body(14),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            reachedAt != null
                ? l10n.shareReachedAt(goal, formatTime(reachedAt, locale))
                : day.isToday
                ? l10n.shareGoalOnly(goal)
                : l10n.shareGoalMissed(
                    goal,
                    formatGrams(gramsLeft(total, day.goal).toDouble(), locale),
                  ),
            style: _body(13.5),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),
          Expanded(
            child: protein.isEmpty
                ? Center(child: Text(l10n.todayEntryCount(0), style: _body(15)))
                : LayoutBuilder(
                    builder: (context, constraints) {
                      // As many lines as fit, 6 at most, keeping a line for
                      // the entries left out.
                      const line = _timelineLine + 7;
                      var count = min(
                        timelineMaxEntries,
                        (constraints.maxHeight / line).floor(),
                      );
                      if (count < protein.length) {
                        count = min(
                          count,
                          ((constraints.maxHeight - 18) / line).floor(),
                        );
                      }
                      final shown = protein.take(max(0, count)).toList();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final entry in shown)
                            _TimelineLine(
                              entry: entry,
                              most: most,
                              showProducts: showProducts,
                            ),
                          if (protein.length > shown.length)
                            Text(
                              l10n.shareMoreEntries(
                                protein.length - shown.length,
                              ),
                              style: _body(12.5),
                              maxLines: 1,
                            ),
                        ],
                      );
                    },
                  ),
          ),
          const SizedBox(height: 8),
          if (total > 0) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 10,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final slot in DaySlot.values)
                      if (bySlot[slot]! > 0)
                        Expanded(
                          flex: (bySlot[slot]! / total * 1000).round().clamp(
                            1,
                            1000,
                          ),
                          child: ColoredBox(color: AppColors.slot(slot)),
                        ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 7),
            Wrap(
              spacing: 12,
              children: [
                for (final slot in DaySlot.values)
                  if (bySlot[slot]! > 0)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppColors.slot(slot),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${slotName(slot)} '
                          '${NumberFormat.percentPattern(locale).format(bySlot[slot]! / total)}',
                          style: _body(11.5),
                        ),
                      ],
                    ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Height of a line of the timeline, without the space under it.
const _timelineLine = 20.0;

class _TimelineLine extends StatelessWidget {
  const _TimelineLine({
    required this.entry,
    required this.most,
    required this.showProducts,
  });

  final Entry entry;

  /// Grams of the largest entry, filling the width.
  final double most;
  final bool showProducts;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = context.localeName;
    final named = showProducts && entry.name != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: SizedBox(
        height: _timelineLine,
        child: Row(
          children: [
            SizedBox(
              width: 62,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  formatTime(entry.createdAt, locale),
                  style: _body(12.5),
                  maxLines: 1,
                ),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // With its name, the bar keeps to the first half.
                  final room = constraints.maxWidth * (named ? 0.45 : 1);
                  return Row(
                    children: [
                      Container(
                        width: max(6, room * entry.proteinGrams / most),
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppColors.slot(entry.slot),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      if (named) ...[
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            entry.name!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _body(12.5, color: _colors.text),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Text(
              l10n.grams(formatGrams(entry.proteinGrams, locale)),
              style: _display(16, weight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
