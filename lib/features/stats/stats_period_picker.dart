part of 'stats_page.dart';

/// The period shown, between the buttons going to the previous and the next
/// one.
class _PeriodBar extends StatelessWidget {
  const _PeriodBar({
    required this.period,
    required this.today,
    required this.onPrevious,
    required this.onNext,
    required this.onChoose,
  });

  final StatsPeriod period;
  final DateTime today;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  /// Opens the choice of the period, when its name is tapped.
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = context.localeName;
    final label = switch (period.span) {
      StatsSpan.week => l10n.statsWeekOf(
        formatDayMonth(period.start, locale, now: today),
      ),
      StatsSpan.month => formatMonth(period.start, locale),
      StatsSpan.year => '${period.start.year}',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          IconButton(
            onPressed: onPrevious,
            tooltip: l10n.statsPrevious,
            icon: const Icon(LucideIcons.chevronLeft),
          ),
          Expanded(
            child: Center(
              child: Semantics(
                liveRegion: true,
                button: true,
                hint: l10n.statsChoosePeriod,
                child: InkWell(
                  onTap: onChoose,
                  customBorder: const StadiumBorder(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          LucideIcons.chevronDown,
                          size: 18,
                          color: AppColors.of(context).textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: onNext,
            tooltip: l10n.statsNext,
            icon: const Icon(LucideIcons.chevronRight),
          ),
        ],
      ),
    );
  }
}

/// Centered window of the months of a year, or of the years, to pick the
/// period to show from: those
/// from [first] to [today], the one of [period] selected.
class _PeriodPicker extends StatefulWidget {
  const _PeriodPicker({
    required this.period,
    required this.first,
    required this.today,
  });

  final StatsPeriod period;
  final DateTime first;
  final DateTime today;

  @override
  State<_PeriodPicker> createState() => _PeriodPickerState();
}

class _PeriodPickerState extends State<_PeriodPicker> {
  /// Year whose months are shown.
  late int _year = widget.period.start.year;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final locale = context.localeName;
    final first = widget.first;
    final today = widget.today;
    final months = widget.period.span == StatsSpan.month;

    Widget option(String label, DateTime value, {required bool enabled}) {
      final selected = months
          ? widget.period.start.year == value.year &&
                widget.period.start.month == value.month
          : widget.period.start.year == value.year;
      return Semantics(
        selected: selected,
        child: Material(
          color: selected ? colors.selection : colors.surface,
          shape: const StadiumBorder(),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: enabled ? () => Navigator.of(context).pop(value) : null,
            child: Center(
              child: Text(
                label,
                style: textTheme.bodyLarge!.copyWith(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected
                      ? colors.onAccent
                      : enabled
                      ? colors.text
                      : colors.textSecondary.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final name = DateFormat.MMM(locale);
    final options = months
        ? [
            for (var month = 1; month <= 12; month++)
              option(
                toBeginningOfSentenceCase(name.format(DateTime(_year, month))),
                DateTime(_year, month),
                enabled:
                    !DateTime(
                      _year,
                      month + 1,
                    ).isBefore(DateTime(first.year, first.month + 1)) &&
                    !DateTime(_year, month).isAfter(today),
              ),
          ]
        : [
            for (var year = first.year; year <= today.year; year++)
              option('$year', DateTime(year), enabled: true),
          ];

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              months ? l10n.statsPickMonth : l10n.statsPickYear,
              style: textTheme.titleSmall!.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            if (months)
              Row(
                children: [
                  IconButton(
                    onPressed: _year > first.year
                        ? () => setState(() => _year--)
                        : null,
                    tooltip: l10n.statsPreviousYear,
                    icon: const Icon(LucideIcons.chevronLeft),
                  ),
                  Expanded(
                    child: Text(
                      '$_year',
                      textAlign: TextAlign.center,
                      style: textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: _year < today.year
                        ? () => setState(() => _year++)
                        : null,
                    tooltip: l10n.statsNextYear,
                    icon: const Icon(LucideIcons.chevronRight),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: months ? 4 : 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: months ? 1.6 : 2.2,
              children: options,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.cancel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
