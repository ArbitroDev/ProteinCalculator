import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:protein_calculator/core/database/entries_dao.dart';
import 'package:protein_calculator/core/domain/app_day.dart';
import 'package:protein_calculator/core/domain/day_slot.dart';
import 'package:protein_calculator/core/domain/grams.dart';
import 'package:protein_calculator/core/formatting.dart';
import 'package:protein_calculator/core/providers.dart';
import 'package:protein_calculator/core/router.dart';
import 'package:protein_calculator/core/stats/period_stats.dart';
import 'package:protein_calculator/core/stats/stats_period.dart';
import 'package:protein_calculator/core/theme.dart';
import 'package:protein_calculator/core/widgets/content_width.dart';
import 'package:protein_calculator/core/widgets/empty_state.dart';
import 'package:protein_calculator/core/widgets/locale_name.dart';
import 'package:protein_calculator/core/widgets/pill_tabs.dart';
import 'package:protein_calculator/core/widgets/slot_name.dart';
import 'package:protein_calculator/features/share/share_choices.dart';
import 'package:protein_calculator/features/share/share_sheet.dart';
import 'package:protein_calculator/features/stats/stats_providers.dart';
import 'package:protein_calculator/features/stats/stats_widgets.dart';
import 'package:protein_calculator/l10n/app_localizations.dart';

part 'stats_period_picker.dart';
part 'stats_cards.dart';
part 'stats_insights.dart';

/// Statistics tab: protein, creatine and workouts over a week, a month or a
/// year, and what they tell together.
class StatsPage extends ConsumerStatefulWidget {
  const StatsPage({super.key});

  @override
  ConsumerState<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends ConsumerState<StatsPage> {
  /// Statistics last shown, kept while those of another period are read.
  PeriodStats? _shown;

  void _show(StatsPeriod period, int todayKey) => ref
      .read(statsDateProvider.notifier)
      .show(period.contains(todayKey) ? null : period.start);

  /// Lets the user pick the period to show among those from the first app
  /// day to today: a day of the week, a month of a year, or a year.
  Future<void> _choose(
    StatsPeriod period, {
    required int firstKey,
    required DateTime today,
  }) async {
    final first = dateOfDayKey(firstKey);
    final firstWeekday = MaterialLocalizations.of(context).firstDayOfWeekIndex;
    final DateTime? picked;
    if (period.span == StatsSpan.week) {
      final l10n = AppLocalizations.of(context);
      final start = period.start.isBefore(first) ? first : period.start;
      picked = await showDatePicker(
        context: context,
        initialDate: start.isAfter(today) ? today : start,
        firstDate: first,
        lastDate: today,
        helpText: l10n.statsPickWeek,
      );
    } else {
      // Centered, as the calendar of a week.
      picked = await showDialog<DateTime>(
        context: context,
        builder: (context) =>
            _PeriodPicker(period: period, first: first, today: today),
      );
    }
    if (picked == null || !mounted) return;
    _show(
      StatsPeriod.containing(period.span, picked, firstWeekday: firstWeekday),
      dayKeyOfDate(today),
    );
  }

  void _selectSpan(StatsSpan span, StatsPeriod period, int todayKey) {
    // The current period stays current; another one gives its middle.
    ref
        .read(statsDateProvider.notifier)
        .show(period.contains(todayKey) ? null : period.middle);
    ref.read(statsSpanProvider.notifier).select(span);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final todayKey = ref.watch(currentDayKeyProvider).value;
    final firstKey = ref.watch(firstAppDayKeyProvider);
    final history = ref.watch(historyProvider).value;
    final span = ref.watch(statsSpanProvider);
    final date = ref.watch(statsDateProvider);
    final firstWeekday = MaterialLocalizations.of(context).firstDayOfWeekIndex;

    Widget body;
    VoidCallback? share;
    if (todayKey == null || firstKey == null || history == null) {
      body = const SizedBox.shrink();
    } else if (history.isEmpty) {
      body = EmptyState(l10n.statsEmpty);
    } else {
      final today = dateOfDayKey(todayKey);
      var period = StatsPeriod.containing(
        span,
        date ?? today,
        firstWeekday: firstWeekday,
      );
      // A period of days to come, or before the app was used, has nothing to
      // tell: the current one instead.
      if (period.firstKey > todayKey || period.lastKey < firstKey) {
        period = StatsPeriod.containing(
          span,
          today,
          firstWeekday: firstWeekday,
        );
      }
      final stats =
          ref.watch(
            periodStatsProvider((period: period, firstWeekday: firstWeekday)),
          ) ??
          _shown;
      _shown = stats;
      // Not while the period shown is still the one before.
      if (stats != null && stats.period == period) {
        share = () =>
            showShareSheet(context, statsShareChoices(context, stats, today));
      }
      final canGoBack = period.firstKey > firstKey;
      final canGoForward = period.lastKey < todayKey;

      final spans = PillTabs(
        labels: {
          StatsSpan.week: l10n.statsWeek,
          StatsSpan.month: l10n.statsMonth,
          StatsSpan.year: l10n.statsYear,
        },
        selected: span,
        onChanged: (value) => _selectSpan(value, period, todayKey),
      );
      final periodBar = _PeriodBar(
        period: period,
        today: today,
        onPrevious: canGoBack ? () => _show(period.previous, todayKey) : null,
        onNext: canGoForward ? () => _show(period.next, todayKey) : null,
        onChoose: () => _choose(period, firstKey: firstKey, today: today),
      );
      body = stats == null
          ? const SizedBox.shrink()
          : GestureDetector(
              onHorizontalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                if (velocity > 300 && canGoBack) {
                  _show(period.previous, todayKey);
                } else if (velocity < -300 && canGoForward) {
                  _show(period.next, todayKey);
                }
              },
              child: _StatsContent(
                stats: stats,
                spans: spans,
                periodBar: periodBar,
                todayKey: todayKey,
              ),
            );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tabStats),
        actions: [
          if (share != null) ShareButton(onPressed: share),
          const SizedBox(width: shareButtonEndGap),
        ],
      ),
      // In landscape, the two columns take the width of the screen.
      body: ContentWidth(
        maxWidth: MediaQuery.orientationOf(context) == Orientation.landscape
            ? double.infinity
            : 640,
        child: body,
      ),
    );
  }
}

/// The cards of a period, under the choice of the [spans] and the
/// [periodBar], which stays at the top once scrolled to: in one column, or in
/// landscape in two of the same width, the protein beside the rest.
class _StatsContent extends ConsumerWidget {
  const _StatsContent({
    required this.stats,
    required this.spans,
    required this.periodBar,
    required this.todayKey,
  });

  final PeriodStats stats;
  final Widget spans;
  final Widget periodBar;
  final int todayKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final goal = ref.watch(dailyGoalProvider).value;
    final entryDays = {
      for (final day
          in ref.watch(historyProvider).value ?? const <DaySummary>[])
        day.dayKey,
    };
    final workoutDays = ref.watch(hevySessionDaysProvider).value ?? const {};

    final main = <Widget>[
      if (stats.hasEntries)
        _ProteinCard(
          stats: stats,
          goal: goal,
          // A day opens on its entries, or on its workouts when it has none.
          canOpen: (dayKey) =>
              entryDays.contains(dayKey) || workoutDays.contains(dayKey),
        )
      else
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 20),
          child: Text(
            l10n.statsNoEntry,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge!
                .copyWith(color: colors.textSecondary),
          ),
        ),
    ];
    final others = <Widget>[
      if (stats.creatine case final creatine?)
        _CreatineCard(stats: creatine, period: stats.period),
      if (stats.workouts case final workouts?)
        _WorkoutsCard(stats: workouts, period: stats.period),
      if (stats.hasEntries && !stats.cross.isEmpty)
        _InsightsCard(stats: stats.cross, goal: stats.protein.averageGoal),
    ];

    // The span scrolls away with the cards, which it changes the look of;
    // the period stays at the top, so that it can change while a card is
    // read.
    final background = AppColors.of(context).background;
    Widget scroll(List<Widget> cards, {required EdgeInsets padding}) =>
        CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(padding.left, 0, padding.right, 0),
              sliver: SliverToBoxAdapter(child: spans),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _PinnedBar(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    padding.left,
                    0,
                    padding.right,
                    0,
                  ),
                  child: periodBar,
                ),
                color: background,
              ),
            ),
            SliverPadding(
              padding: padding,
              sliver: SliverList.list(children: cards),
            ),
          ],
        );

    if (MediaQuery.orientationOf(context) == Orientation.landscape) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: scroll(
              main,
              padding: const EdgeInsets.fromLTRB(18, 4, 8, 24),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(8, 8, 18, 24),
              children: others,
            ),
          ),
        ],
      );
    }
    return scroll([
      ...main,
      ...others,
    ], padding: const EdgeInsets.fromLTRB(18, 4, 18, 24));
  }
}

/// The [child] of a scroll view staying at its top once scrolled to, on the
/// [color] of the page so that what scrolls under it does not show.
class _PinnedBar extends SliverPersistentHeaderDelegate {
  const _PinnedBar({required this.child, required this.color});

  final Widget child;
  final Color color;

  /// Height of the period bar: its buttons and their padding.
  static const _height = 60.0;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => ColoredBox(color: color, child: child);

  @override
  bool shouldRebuild(_PinnedBar oldDelegate) =>
      oldDelegate.child != child || oldDelegate.color != color;
}
