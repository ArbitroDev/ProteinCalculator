import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:protein_calculator/core/domain/app_day.dart';
import 'package:protein_calculator/core/domain/day_progress.dart';
import 'package:protein_calculator/core/formatting.dart';
import 'package:protein_calculator/core/providers.dart';
import 'package:protein_calculator/core/router.dart';
import 'package:protein_calculator/core/theme.dart';
import 'package:protein_calculator/core/widgets/locale_name.dart';
import 'package:protein_calculator/l10n/app_localizations.dart';

/// Calendar view of the history: the days of each month, colored by how far
/// each went towards the goal it had. The current month comes first; the
/// months before follow below it, back to the first goal. The month being
/// read, the one taking the most room on screen, shows fully; the others
/// are dimmed. Tap a day with entries to see them.
class CalendarView extends ConsumerStatefulWidget {
  const CalendarView({super.key});

  @override
  ConsumerState<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends ConsumerState<CalendarView> {
  final _scroll = ScrollController();

  /// Index of the month being read, 0 for the current month.
  int _focused = 0;

  /// Heights of the months, from the top of the list, as last laid out.
  List<double> _heights = const [];

  /// Height of the initials laid over the top of the list, which scrolls
  /// behind them.
  double _topInset = 0;

  /// Height of the legend laid over the bottom of the list.
  double _bottomInset = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_updateFocus);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// The month being read is the one taking the most room on screen.
  void _updateFocus() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    // What the initials and the legend do not hide.
    final viewTop = position.pixels + _topInset;
    final viewBottom =
        position.pixels + position.viewportDimension - _bottomInset;
    var top = max(0.0, _topInset - _Fade.height);
    var focused = 0;
    var mostVisible = 0.0;
    for (final (index, height) in _heights.indexed) {
      final visible = min(top + height, viewBottom) - max(top, viewTop);
      if (visible > mostVisible) {
        mostVisible = visible;
        focused = index;
      }
      top += height;
      if (top > viewBottom) break;
    }
    if (focused != _focused) setState(() => _focused = focused);
  }

  static const _sidePadding = 16.0;

  @override
  Widget build(BuildContext context) {
    final todayKey = ref.watch(currentDayKeyProvider).value;
    final goals = ref.watch(goalChangesProvider).value;
    final days = ref.watch(historyProvider).value;
    if (todayKey == null || goals == null || days == null) {
      return const SizedBox.shrink();
    }

    final today = dateOfDayKey(todayKey);
    final first = dateOfDayKey(
      goals.isEmpty ? todayKey : min(goals.first.dayKey, todayKey),
    );
    final count =
        (today.year - first.year) * 12 + today.month - first.month + 1;
    final totals = {for (final day in days) day.dayKey: day.proteinGrams};
    final firstWeekday = MaterialLocalizations.of(context).firstDayOfWeekIndex;
    DateTime monthAt(int index) => DateTime(today.year, today.month - index);

    final background = AppColors.of(context).background;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final cell =
                        (constraints.maxWidth - _sidePadding * 2 - _gap * 6) /
                        7;
                    _heights = [
                      for (var index = 0; index < count; index++)
                        _MonthSection.heightOf(
                          monthAt(index),
                          firstWeekday,
                          cell,
                        ),
                    ];
                    return ListView.builder(
                      controller: _scroll,
                      // Starts right under the initials: the fade only shows once
                      // the list scrolls. Ends right on the legend.
                      padding: EdgeInsets.fromLTRB(
                        _sidePadding,
                        max(0, _topInset - _Fade.height),
                        _sidePadding,
                        _bottomInset,
                      ),
                      itemCount: count,
                      // The same heights as the focus uses, so both agree.
                      itemExtentBuilder: (index, _) =>
                          index < count ? _heights[index] : null,
                      itemBuilder: (context, index) => AnimatedOpacity(
                        opacity: index == _focused ? 1 : 0.45,
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 220),
                        child: _MonthSection(
                          month: monthAt(index),
                          todayKey: todayKey,
                          totals: totals,
                          goals: goals,
                        ),
                      ),
                    );
                  },
                ),
              ),
              // The initials on the page background, fading downwards, so the
              // days scrolling behind them disappear softly.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _Measured(
                  onHeight: (height) {
                    if (mounted) setState(() => _topInset = height);
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AbsorbPointer(
                        child: ColoredBox(
                          color: background,
                          child: const Padding(
                            padding: EdgeInsets.fromLTRB(16, 2, 16, 0),
                            child: _WeekdayRow(),
                          ),
                        ),
                      ),
                      // Shows as the list scrolls, so it never fades the first
                      // title at rest.
                      ListenableBuilder(
                        listenable: _scroll,
                        builder: (context, child) => Opacity(
                          opacity: _scroll.hasClients
                              ? (_scroll.offset / _Fade.height).clamp(0, 1)
                              : 0,
                          child: child,
                        ),
                        child: _Fade(color: background),
                      ),
                    ],
                  ),
                ),
              ),
              // The legend over the bottom of the list: the days pass
              // behind it, and show around its top corners rather than
              // being cut straight.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _Measured(
                  onHeight: (height) {
                    if (mounted) setState(() => _bottomInset = height);
                  },
                  child: Stack(
                    children: [
                      // The page background from the middle of the card
                      // down, so its bottom corners and the space under it
                      // stay clear.
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 24,
                        bottom: 0,
                        child: AbsorbPointer(
                          child: ColoredBox(color: background),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: AbsorbPointer(child: _Legend()),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Band going from [color] to transparent, downwards.
class _Fade extends StatelessWidget {
  const _Fade({required this.color});

  static const height = 24.0;

  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color, color.withValues(alpha: 0)],
        ),
      ),
    ),
  );
}

/// Reports the height of [child] once laid out, and again when it changes.
class _Measured extends SingleChildRenderObjectWidget {
  const _Measured({required this.onHeight, required super.child});

  final ValueChanged<double> onHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasured(onHeight);

  @override
  void updateRenderObject(BuildContext context, _RenderMeasured renderObject) =>
      renderObject.onHeight = onHeight;
}

class _RenderMeasured extends RenderProxyBox {
  _RenderMeasured(this.onHeight);

  ValueChanged<double> onHeight;
  double? _reported;

  @override
  void performLayout() {
    super.performLayout();
    final height = size.height;
    if (height == _reported) return;
    _reported = height;
    // After the frame: the list is laid out again with the new padding.
    WidgetsBinding.instance.addPostFrameCallback((_) => onHeight(height));
  }
}

/// Space between two columns of days, and between two weeks.
const _gap = 6.0;

/// Height under each bubble for its marks, two side by side at most.
const _marksHeight = 16.0;

/// Space between two weeks.
const _weekGap = 4.0;

/// Initials of the days of the week, starting on the first day of the week
/// of the user's language, each above its column.
class _WeekdayRow extends StatelessWidget {
  const _WeekdayRow();

  @override
  Widget build(BuildContext context) {
    final material = MaterialLocalizations.of(context);
    final style = Theme.of(context).textTheme.bodySmall!.copyWith(
      color: AppColors.of(context).textSecondary,
      fontWeight: FontWeight.w600,
    );
    return ExcludeSemantics(
      child: Row(
        spacing: _gap,
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Text(
                material.narrowWeekdays[(material.firstDayOfWeekIndex + i) % 7],
                textAlign: TextAlign.center,
                style: style,
              ),
            ),
        ],
      ),
    );
  }
}

/// Title and weeks of [month].
class _MonthSection extends StatelessWidget {
  const _MonthSection({
    required this.month,
    required this.todayKey,
    required this.totals,
    required this.goals,
  });

  final DateTime month;
  final int todayKey;

  /// Protein grams of each app day having entries.
  final Map<int, double> totals;
  final List<({int dayKey, double grams})> goals;

  /// Height of the title above the weeks.
  static const _titleHeight = 46.0;

  /// Space under the last week, before the next month.
  static const _bottomSpace = 22.0;

  /// Empty days before the first of [month], to start the week on
  /// [firstWeekday] (0 for Sunday, as the localizations count).
  static int _blanks(DateTime month, int firstWeekday) =>
      // DateTime counts Monday as 1 and Sunday as 7.
      (month.weekday % 7 - firstWeekday + 7) % 7;

  /// Height of the section of [month] with days [cell] wide.
  static double heightOf(DateTime month, int firstWeekday, double cell) {
    final length = DateTime(month.year, month.month + 1, 0).day;
    final weeks = (_blanks(month, firstWeekday) + length + 6) ~/ 7;
    return _titleHeight +
        weeks * (cell + _marksHeight) +
        (weeks - 1) * _weekGap +
        _bottomSpace;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final blanks = _blanks(
      month,
      MaterialLocalizations.of(context).firstDayOfWeekIndex,
    );
    final length = DateTime(month.year, month.month + 1, 0).day;
    final start = goals.isEmpty ? null : goals.first.dayKey;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: _titleHeight,
          child: Container(
            alignment: Alignment.bottomLeft,
            padding: const EdgeInsets.only(bottom: 10),
            child: Semantics(
              header: true,
              child: Text(
                formatMonth(month, context.localeName),
                style: textTheme.headlineSmall!.copyWith(fontSize: 22),
              ),
            ),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final cell = (constraints.maxWidth - _gap * 6) / 7;
            return GridView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                crossAxisSpacing: _gap,
                mainAxisSpacing: _weekGap,
                mainAxisExtent: cell + _marksHeight,
              ),
              children: [
                for (var i = 0; i < blanks; i++) const SizedBox.shrink(),
                for (var day = 1; day <= length; day++)
                  _dayCell(
                    month.year * 10000 + month.month * 100 + day,
                    start: start,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _dayCell(int dayKey, {required int? start}) {
    final total = totals[dayKey];
    final goal = goalOn(dayKey, goals);
    // Days to come, and those before the app was used, have no color.
    final tracked =
        dayKey <= todayKey && start != null && dayKey >= start && goal != null;
    return _DayCell(
      dayKey: dayKey,
      progress: tracked ? DayProgress.of(total ?? 0, goal) : null,
      isToday: dayKey == todayKey,
      isFuture: dayKey > todayKey,
      hasEntries: total != null,
    );
  }
}

/// Fill and text colors of a day for its [DayProgress].
({Color fill, Color text}) _progressColors(
  DayProgress progress,
  AppColors colors,
) => switch (progress) {
  DayProgress.none => (fill: colors.surface, text: colors.textSecondary),
  DayProgress.low => (
    fill: Color.alphaBlend(
      AppColors.accent.withValues(alpha: 0.3),
      colors.surface,
    ),
    text: colors.text,
  ),
  DayProgress.half => (fill: AppColors.progressHalf, text: AppColors.onAccent),
  DayProgress.reached => (fill: AppColors.accent, text: AppColors.onAccent),
};

/// A day: a bubble with its number in the middle, colored by its progress,
/// and under it the marks of the day, two side by side at most.
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.dayKey,
    required this.progress,
    required this.isToday,
    required this.isFuture,
    required this.hasEntries,
  });

  final int dayKey;

  /// Null for a day without color: to come, or before the app was used.
  final DayProgress? progress;
  final bool isToday;
  final bool isFuture;
  final bool hasEntries;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final progress = this.progress;
    final style = progress == null
        ? (
            fill: Colors.transparent,
            text: colors.textSecondary.withValues(alpha: isFuture ? 0.5 : 1),
          )
        : _progressColors(progress, colors);

    final marks = [
      if (progress == DayProgress.reached)
        // The mark of the days reaching their goal in the history.
        Icon(LucideIcons.circleCheck, size: 12, color: colors.accentText),
    ];

    return Semantics(
      label: [
        formatLongDate(dateOfDayKey(dayKey), context.localeName),
        if (progress != null) _progressLabel(l10n, progress),
      ].join(', '),
      button: hasEntries,
      excludeSemantics: true,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Material(
              color: style.fill,
              shape: CircleBorder(
                side: isToday
                    ? BorderSide(color: colors.structure, width: 2)
                    : BorderSide.none,
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: hasEntries
                    ? () => context.go(AppRoutes.historyDay(dayKey))
                    : null,
                child: Center(
                  child: Text(
                    '${dayKey % 100}',
                    style: textTheme.bodyLarge!.copyWith(
                      fontSize: 15,
                      height: 1,
                      color: style.text,
                      fontWeight: isToday || progress == DayProgress.reached
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 2,
              children: marks,
            ),
          ),
        ],
      ),
    );
  }
}

String _progressLabel(AppLocalizations l10n, DayProgress progress) =>
    switch (progress) {
      DayProgress.none => l10n.calendarNone,
      DayProgress.low => l10n.calendarLow,
      DayProgress.half => l10n.calendarHalf,
      DayProgress.reached => l10n.calendarReached,
    };

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final style = Theme.of(context).textTheme.bodySmall!
        .copyWith(color: colors.textSecondary);

    Widget item(DayProgress progress) => Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: _progressColors(progress, colors).fill,
            shape: BoxShape.circle,
            border: progress == DayProgress.none
                ? Border.all(color: colors.divider)
                : null,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            _progressLabel(l10n, progress),
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (progress == DayProgress.reached) ...[
          const SizedBox(width: 4),
          Icon(LucideIcons.circleCheck, size: 12, color: colors.accentText),
        ],
      ],
    );

    return ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.divider),
        ),
        child: Column(
          spacing: 6,
          children: [
            for (final pair in [
              [DayProgress.none, DayProgress.low],
              [DayProgress.half, DayProgress.reached],
            ])
              Row(
                spacing: 12,
                children: [
                  for (final progress in pair) Expanded(child: item(progress)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
