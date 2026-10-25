import 'dart:math';

import 'package:collection/collection.dart';
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
import 'package:protein_calculator/core/widgets/creatine_mark.dart';
import 'package:protein_calculator/core/widgets/hevy_mark.dart';
import 'package:protein_calculator/core/widgets/locale_name.dart';
import 'package:protein_calculator/core/widgets/shaker_icon.dart';
import 'package:protein_calculator/core/widgets/sliding_selector.dart';
import 'package:protein_calculator/l10n/app_localizations.dart';

/// Calendar view of the history: the days of each month, colored by how far
/// each went towards the goal it had. The current month comes last, right
/// above the legend, and shows first; the months before go up above it, back
/// to the first goal. The month being read, the one taking the most room on
/// screen, shows fully; the others are dimmed. Tap a day with entries or a
/// Hevy workout to see them. Those who track creatine, or imported their Hevy
/// workouts, can color the days by creatine taken or by workout instead, with
/// the filter above the legend. In landscape, as the details of a day, the
/// month being read, the filter and the legend go on the left, the days on
/// the right.
class CalendarView extends ConsumerStatefulWidget {
  const CalendarView({super.key});

  @override
  ConsumerState<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends ConsumerState<CalendarView> {
  final _scroll = ScrollController();

  /// Index of the month being read, 0 for the current month.
  int _focused = 0;

  /// Heights of the months, from the bottom of the list, as last laid out.
  List<double> _heights = const [];

  /// Height of the legend laid over the bottom of the list.
  double _legendHeight = 0;

  /// Whether the screen is in landscape, the legend then beside the list.
  bool _landscape = false;

  /// What the legend hides of the bottom of the list: nothing in landscape.
  double get _bottomInset => _landscape ? 0 : _legendHeight;

  /// Whether the legend was measured: until then, the list would place the
  /// current month behind it, then jump up, and stays hidden.
  bool _measured = false;

  /// Space under the current month: the legend, and the room the months
  /// leave when they do not fill the screen.
  double _bottomPadding = 0;

  /// How far the list can still scroll up, towards the oldest month.
  final _scrollLeft = ValueNotifier<double>(0);

  /// What colors the days.
  CalendarMode _mode = CalendarMode.protein;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _scrollLeft.dispose();
    super.dispose();
  }

  /// On a scroll, and once the list knows its length.
  void _onScroll() {
    if (!_scroll.hasClients || !_scroll.position.hasContentDimensions) return;
    final position = _scroll.position;
    _scrollLeft.value = position.maxScrollExtent - position.pixels;
    _updateFocus(position);
  }

  /// The month being read is the one taking the most room on screen.
  void _updateFocus(ScrollPosition position) {
    // The list runs upwards from the legend: its offsets count from the
    // bottom. What the legend and the fade do not hide.
    final viewBottom = position.pixels + _bottomInset;
    final viewTop = position.pixels + position.viewportDimension - _Fade.height;
    var bottom = _bottomPadding;
    var focused = 0;
    var mostVisible = 0.0;
    for (final (index, height) in _heights.indexed) {
      final visible = min(bottom + height, viewTop) - max(bottom, viewBottom);
      if (visible > mostVisible) {
        mostVisible = visible;
        focused = index;
      }
      bottom += height;
      if (bottom > viewTop) break;
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
    // From the first day the app was used, or the oldest entry, added
    // afterwards for an earlier day.
    final first = dateOfDayKey(
      firstAppDayKey(
        todayKey: todayKey,
        firstGoalDayKey: goals.isEmpty ? null : goals.first.dayKey,
        entryDayKeys: days.map((day) => day.dayKey),
      ),
    );
    final count =
        (today.year - first.year) * 12 + today.month - first.month + 1;
    final totals = {for (final day in days) day.dayKey: day.proteinGrams};
    final creatineDays = {
      for (final day in days)
        if (day.creatineDoses > 0) day.dayKey,
    };
    // Shown to those who track creatine, or did.
    final creatineShown =
        (ref.watch(creatineSettingsProvider).value?.everEnabled ?? false) ||
        creatineDays.isNotEmpty;
    final hevyDays = ref.watch(shownHevyDaysProvider);
    // Shown while Hevy workouts are imported.
    final hevyShown = ref.watch(hevyImportedAtProvider).value != null;
    final options = _modesOf(creatine: creatineShown, hevy: hevyShown);
    // Back to protein when the option chosen is no longer offered.
    final mode = options.contains(_mode) ? _mode : CalendarMode.protein;
    // Only with something to choose from.
    final filtered = options.length > 1;
    final firstWeekday = MaterialLocalizations.of(context).firstDayOfWeekIndex;
    DateTime monthAt(int index) => DateTime(today.year, today.month - index);

    final background = AppColors.of(context).background;
    _landscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    final gap = _landscape ? _landscapeGap : _gap;
    final filter = filtered
        ? _ModeFilter(
            options: options,
            selected: mode,
            onChanged: (value) => setState(() => _mode = value),
          )
        : null;
    final legend = AbsorbPointer(
      child: _Legend(
        mode: mode,
        creatine: creatineShown,
        hevy: hevyShown,
        oneColumn: _landscape,
      ),
    );
    final calendar = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Above the list rather than over it: the oldest month, once
        // reached, stops right under it, a little apart.
        Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, _landscape ? 6 : 2),
          child: _WeekdayRow(gap: gap),
        ),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: Opacity(
                  opacity: _measured || _landscape ? 1 : 0,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final cell =
                          (constraints.maxWidth - _sidePadding * 2 - gap * 6) /
                          7;
                      _heights = [
                        for (var index = 0; index < count; index++)
                          _MonthSection.heightOf(
                            monthAt(index),
                            firstWeekday,
                            cell,
                            titled: !_landscape,
                          ),
                      ];
                      // The months not filling the screen stay right under the
                      // initials rather than on the legend: the room left goes
                      // under the current month, where the list starts.
                      final space =
                          constraints.maxHeight -
                          _bottomInset -
                          _heights.fold(0.0, (sum, height) => sum + height);
                      _bottomPadding = _bottomInset + max(0, space);
                      return NotificationListener<ScrollMetricsNotification>(
                        onNotification: (_) {
                          _onScroll();
                          return false;
                        },
                        child: ListView.builder(
                          controller: _scroll,
                          // From the current month, at the bottom, up to the
                          // oldest one.
                          reverse: true,
                          // Ends right under the initials: the fade goes once
                          // the oldest month shows.
                          padding: EdgeInsets.fromLTRB(
                            _sidePadding,
                            0,
                            _sidePadding,
                            _bottomPadding,
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
                              creatineDays: creatineDays,
                              hevyDays: hevyDays,
                              goals: goals,
                              mode: mode,
                              titled: !_landscape,
                              gap: gap,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              // The top of the list fading into the page background, so the
              // days scrolling under the initials disappear softly. Goes as
              // the oldest month comes in, so it never fades its title.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: ValueListenableBuilder(
                  valueListenable: _scrollLeft,
                  builder: (context, scrollLeft, child) => Opacity(
                    opacity: (scrollLeft / _Fade.height).clamp(0, 1),
                    child: child,
                  ),
                  child: _Fade(color: background),
                ),
              ),
              // The filter and the legend over the bottom of the list: the
              // days pass behind them, and show around the top corners of
              // the first rather than being cut straight.
              if (!_landscape)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _Measured(
                    onHeight: (height) {
                      if (mounted) {
                        setState(() {
                          _legendHeight = height;
                          _measured = true;
                        });
                      }
                    },
                    child: Stack(
                      children: [
                        // The page background from the middle of the card
                        // down, so its bottom corners and the space under it
                        // stay clear. The filter floats above it, over the
                        // days.
                        Positioned(
                          left: 0,
                          right: 0,
                          top: filtered ? 24 + _ModeFilter.height + 8 : 24,
                          bottom: 0,
                          child: AbsorbPointer(
                            child: ColoredBox(color: background),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            spacing: 8,
                            children: [
                              if (filter != null)
                                Align(
                                  alignment: AlignmentDirectional.centerEnd,
                                  child: filter,
                                ),
                              legend,
                            ],
                          ),
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
    if (!_landscape) return calendar;

    // The month being read, the filter and the legend on the left; the
    // days on the right, a little wider, for the room between them.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 2,
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 0, 12),
              child: ConstrainedBox(
                // The legend at the bottom, when there is room for it.
                constraints: BoxConstraints(
                  minHeight: max(0, constraints.maxHeight - 20),
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 8,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          formatMonth(monthAt(_focused), context.localeName),
                          style: Theme.of(context).textTheme.headlineSmall!
                              .copyWith(fontSize: 22),
                        ),
                      ),
                      const Spacer(),
                      ?filter,
                      // As wide as what it tells, not as the column.
                      IntrinsicWidth(child: legend),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Expanded(flex: 3, child: calendar),
      ],
    );
  }
}

/// Small filter of what colors the days, its options shown by their icons
/// only: the shaker of protein, the sparkles of creatine, the dumbbell of the
/// Hevy workouts.
class _ModeFilter extends StatelessWidget {
  const _ModeFilter({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  static const height = 36.0;

  /// Width of each option.
  static const _optionWidth = 44.0;

  /// Space around the options, and between them.
  static const _padding = 3.0;

  /// The modes offered, in order.
  final List<CalendarMode> options;
  final CalendarMode selected;
  final ValueChanged<CalendarMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    // The pill of the option chosen, and its icon: in the black or white of
    // the Hevy workouts while they color the days, in the accent otherwise.
    final pill = selected == CalendarMode.hevy
        ? (fill: colors.hevy, icon: colors.onHevy)
        : (fill: AppColors.selection, icon: AppColors.onAccent);

    return Container(
      width: _optionWidth * options.length + _padding * (options.length + 1),
      height: height,
      padding: const EdgeInsets.all(_padding),
      decoration: ShapeDecoration(
        color: colors.surface,
        shape: StadiumBorder(side: BorderSide(color: colors.divider)),
      ),
      child: SlidingSelector(
        selectedIndex: options.indexOf(selected),
        gap: _padding,
        shape: const StadiumBorder(),
        color: pill.fill,
        children: [
          for (final mode in options)
            Tooltip(
              message: switch (mode) {
                CalendarMode.protein => l10n.formProtein,
                CalendarMode.creatine => l10n.creatine,
                CalendarMode.hevy => l10n.hevyFilter,
              },
              child: Semantics(
                button: true,
                selected: mode == selected,
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: () => onChanged(mode),
                    child: IconTheme(
                      data: IconThemeData(
                        size: 18,
                        color: mode == selected
                            ? pill.icon
                            : colors.textSecondary,
                      ),
                      child: Center(
                        child: switch (mode) {
                          CalendarMode.protein => const ShakerIcon(),
                          CalendarMode.creatine => const Icon(creatineIcon),
                          CalendarMode.hevy => const Icon(hevyIcon),
                        },
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

/// What colors the days of the calendar: how far each went towards its
/// goal, whether creatine was taken, or whether it holds a Hevy workout.
enum CalendarMode { protein, creatine, hevy }

/// Modes the filter offers: protein always, creatine to those who track it,
/// the Hevy workouts while they are imported.
List<CalendarMode> _modesOf({required bool creatine, required bool hevy}) => [
  CalendarMode.protein,
  if (creatine) CalendarMode.creatine,
  if (hevy) CalendarMode.hevy,
];

/// Space between two columns of days.
const _gap = 6.0;

/// Space between two columns of days in landscape, where the days are no
/// taller than the screen leaves them: they stand apart all the more.
const _landscapeGap = 14.0;

/// Height under each bubble for its marks, three side by side at most.
const _marksHeight = 16.0;

/// Space between two weeks.
const _weekGap = 4.0;

/// Initials of the days of the week, starting on the first day of the week
/// of the user's language, each above its column.
class _WeekdayRow extends StatelessWidget {
  const _WeekdayRow({required this.gap});

  /// Space between two columns of days.
  final double gap;

  @override
  Widget build(BuildContext context) {
    final material = MaterialLocalizations.of(context);
    final style = Theme.of(context).textTheme.bodySmall!.copyWith(
      color: AppColors.of(context).textSecondary,
      fontWeight: FontWeight.w600,
    );
    return ExcludeSemantics(
      child: Row(
        spacing: gap,
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

/// Title and weeks of [month]; its weeks only when not [titled], the month
/// being read then told beside the list.
class _MonthSection extends StatelessWidget {
  const _MonthSection({
    required this.month,
    required this.todayKey,
    required this.totals,
    required this.creatineDays,
    required this.hevyDays,
    required this.goals,
    required this.mode,
    this.titled = true,
    this.gap = _gap,
  });

  final DateTime month;
  final int todayKey;

  /// Protein grams of each app day having entries.
  final Map<int, double> totals;

  /// App days creatine was taken.
  final Set<int> creatineDays;

  /// App days with a Hevy workout, from the first app day to today.
  final Set<int> hevyDays;
  final List<({int dayKey, double grams})> goals;
  final CalendarMode mode;
  final bool titled;

  /// Space between two columns of days.
  final double gap;

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
  static double heightOf(
    DateTime month,
    int firstWeekday,
    double cell, {
    bool titled = true,
  }) {
    final length = DateTime(month.year, month.month + 1, 0).day;
    final weeks = (_blanks(month, firstWeekday) + length + 6) ~/ 7;
    return (titled ? _titleHeight : 0) +
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
        if (titled)
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
            final cell = (constraints.maxWidth - gap * 6) / 7;
            return GridView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                crossAxisSpacing: gap,
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
    final workedOut = hevyDays.contains(dayKey);
    // Days to come, and those before the app was used, have no color, but
    // for the days given entries afterwards, or holding a workout: they count
    // with the first goal.
    final tracked =
        dayKey <= todayKey &&
        goal != null &&
        (total != null || workedOut || start != null && dayKey >= start);
    return _DayCell(
      dayKey: dayKey,
      progress: tracked ? DayProgress.of(total ?? 0, goal) : null,
      isToday: dayKey == todayKey,
      isFuture: dayKey > todayKey,
      hasEntries: total != null,
      creatineTaken: creatineDays.contains(dayKey),
      workedOut: workedOut,
      mode: mode,
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

/// Fill and text colors of a day in the creatine mode: blue if creatine was
/// [taken], as a day without protein otherwise.
({Color fill, Color text}) _creatineColors(bool taken, AppColors colors) =>
    taken
    ? (fill: AppColors.creatine, text: AppColors.onAccent)
    : _progressColors(DayProgress.none, colors);

/// Fill and text colors of a day in the Hevy mode: black or white, by the
/// theme, if it [workedOut], as a day without protein otherwise.
({Color fill, Color text}) _hevyColors(bool workedOut, AppColors colors) =>
    workedOut
    ? (fill: colors.hevy, text: colors.onHevy)
    : _progressColors(DayProgress.none, colors);

/// A day: a bubble with its number in the middle, colored by its progress,
/// and under it the marks of the day, three side by side at most.
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.dayKey,
    required this.progress,
    required this.isToday,
    required this.isFuture,
    required this.hasEntries,
    required this.creatineTaken,
    required this.workedOut,
    required this.mode,
  });

  final int dayKey;

  /// Null for a day without color: to come, or before the app was used.
  final DayProgress? progress;
  final bool isToday;
  final bool isFuture;
  final bool hasEntries;
  final bool creatineTaken;

  /// Whether the day holds a Hevy workout.
  final bool workedOut;

  /// Colors the day by its [progress], by whether [creatineTaken], or by
  /// whether it [workedOut]; its marks stay the same.
  final CalendarMode mode;

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
        : switch (mode) {
            CalendarMode.protein => _progressColors(progress, colors),
            CalendarMode.creatine => _creatineColors(creatineTaken, colors),
            CalendarMode.hevy => _hevyColors(workedOut, colors),
          };
    // The days standing out in the colors of the mode.
    final highlighted = switch (mode) {
      CalendarMode.protein => progress == DayProgress.reached,
      CalendarMode.creatine => progress != null && creatineTaken,
      CalendarMode.hevy => progress != null && workedOut,
    };
    // A day opens on its entries, or on its workouts when it has none.
    final opens = hasEntries || workedOut;

    final marks = [
      if (progress == DayProgress.reached)
        // The mark of the days reaching their goal in the history.
        Icon(LucideIcons.circleCheck, size: 12, color: colors.accentText),
      // The mark of the days creatine was taken.
      if (creatineTaken) const CreatineCheck(size: 12),
      // The mark of the days with a Hevy workout.
      if (workedOut) const HevyMark(size: 12),
    ];

    return Semantics(
      label: [
        formatLongDate(dateOfDayKey(dayKey), context.localeName),
        if (progress != null) _progressLabel(l10n, progress),
        if (creatineTaken) l10n.creatineTaken,
        if (workedOut) l10n.hevyWorkout,
      ].join(', '),
      button: opens,
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
                onTap: opens
                    ? () => context.go(AppRoutes.historyDay(dayKey))
                    : null,
                child: Center(
                  child: Text(
                    '${dayKey % 100}',
                    style: textTheme.bodyLarge!.copyWith(
                      fontSize: 15,
                      height: 1,
                      color: style.text,
                      fontWeight: isToday || highlighted
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            // Three marks are wider than the day on the narrowest screens:
            // they shrink to fit.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 2,
                children: marks,
              ),
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
  const _Legend({
    required this.mode,
    required this.creatine,
    required this.hevy,
    this.oneColumn = false,
  });

  /// What colors the days, which the legend tells.
  final CalendarMode mode;

  /// Whether creatine is tracked: the legend tells the mark of the days it
  /// was taken, and the colors of the creatine filter.
  final bool creatine;

  /// Whether Hevy workouts are imported: the legend tells the mark of the
  /// days holding one, and the colors of the Hevy filter.
  final bool hevy;

  /// Whether the legend tells one thing a line, beside the days in
  /// landscape, rather than two.
  final bool oneColumn;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final style = Theme.of(context).textTheme.bodySmall!
        .copyWith(color: colors.textSecondary);

    /// A line of the legend: the dot of [fill], none if null, its [label],
    /// and the [mark] the days show for it.
    Widget item(
      String label, {
      ({Color fill, Color text})? fill,
      bool bordered = false,
      Widget? mark,
    }) => Row(
      children: [
        if (fill == null)
          // No color of its own: lined up with the others, the room of
          // their dot left empty.
          const SizedBox(width: 14)
        else
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: fill.fill,
              shape: BoxShape.circle,
              border: bordered ? Border.all(color: colors.divider) : null,
            ),
          ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (mark != null) ...[const SizedBox(width: 4), mark],
      ],
    );

    final goalMark = Icon(
      LucideIcons.circleCheck,
      size: 12,
      color: colors.accentText,
    );
    const creatineMark = CreatineCheck(size: 12);
    const hevyMark = HevyMark(size: 12);
    List<List<Widget>> rowsOf(CalendarMode mode) => switch (mode) {
      CalendarMode.protein => [
        ...[
          for (final progress in DayProgress.values)
            item(
              _progressLabel(l10n, progress),
              fill: _progressColors(progress, colors),
              bordered: progress == DayProgress.none,
              mark: progress == DayProgress.reached ? goalMark : null,
            ),
        ].slices(2),
        if (creatine || hevy)
          [
            if (creatine) item(l10n.calendarCreatine, mark: creatineMark),
            if (hevy) item(l10n.calendarHevy, mark: hevyMark),
          ],
      ],
      // The marks of the days stay: the others are told too.
      CalendarMode.creatine => [
        [
          item(
            l10n.calendarNone,
            fill: _creatineColors(false, colors),
            bordered: true,
          ),
          item(
            l10n.calendarCreatine,
            fill: _creatineColors(true, colors),
            mark: creatineMark,
          ),
        ],
        [
          item(l10n.calendarReached, mark: goalMark),
          if (hevy) item(l10n.calendarHevy, mark: hevyMark),
        ],
      ],
      // Likewise.
      CalendarMode.hevy => [
        [
          item(
            l10n.calendarNoHevy,
            fill: _hevyColors(false, colors),
            bordered: true,
          ),
          item(
            l10n.calendarHevy,
            fill: _hevyColors(true, colors),
            bordered: true,
            mark: hevyMark,
          ),
        ],
        [
          item(l10n.calendarReached, mark: goalMark),
          if (creatine) item(l10n.calendarCreatine, mark: creatineMark),
        ],
      ],
    };
    final modes = _modesOf(creatine: creatine, hevy: hevy);

    return ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.divider),
        ),
        // As high as the highest legend, whatever the filter: the shorter
        // one leaves room at the bottom of the card, and the list the same
        // room under the current month, so the days do not move when the
        // filter changes.
        child: IndexedStack(
          index: modes.indexOf(mode),
          children: [
            for (final value in modes)
              Column(
                spacing: 6,
                children: [
                  for (final row in [
                    for (final row in rowsOf(value))
                      if (oneColumn) ...[
                        for (final cell in row) [cell],
                      ] else
                        row,
                  ])
                    Row(
                      spacing: 12,
                      children: [
                        for (final cell in row) Expanded(child: cell),
                        if (row.length == 1 && !oneColumn) const Spacer(),
                      ],
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
