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
import 'package:protein_calculator/core/widgets/motion_shaker.dart';
import 'package:protein_calculator/core/widgets/shaker.dart';
import 'package:protein_calculator/core/widgets/undo_snack_bar.dart';
import 'package:protein_calculator/core/widgets/user_action.dart';
import 'package:protein_calculator/features/today/quick_add.dart';
import 'package:protein_calculator/l10n/app_localizations.dart';

/// Main tab: the summary of the current app day, then the shaker with one
/// label per entry next to it. In landscape, the shaker stands on the left
/// and the summary tops the labels.
class TodayPage extends ConsumerStatefulWidget {
  const TodayPage({super.key});

  @override
  ConsumerState<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends ConsumerState<TodayPage> {
  /// Where the quick added favorite falls.
  final _shakerKey = GlobalKey();

  /// Adds the favorite without the form: a drop flies from the button into
  /// the shaker, then the entry lands, with a few seconds to undo.
  Future<void> _quickAdd(Product product, BuildContext button) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final entries = ref.read(databaseProvider).entriesDao;
    if (!MediaQuery.disableAnimationsOf(context)) {
      await flyToShaker(
        from: button,
        shaker: _shakerKey,
        color: AppColors.slot(DaySlot.of(ref.read(clockProvider)())),
      );
    }
    final id = await runUserAction(
      messenger,
      l10n,
      () => quickAdd(ref, product),
    );
    if (id == null) return;
    showUndoSnackBar(
      messenger,
      l10n: l10n,
      label: l10n.quickAdded(product.name),
      onUndo: () =>
          runUserAction(messenger, l10n, () => entries.deleteEntry(id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dayKey = ref.watch(currentDayKeyProvider).value;
    final goal = ref.watch(dailyGoalProvider).value;
    if (dayKey == null || goal == null) return const Scaffold();
    final entries = ref.watch(dayEntriesProvider(dayKey)).value ?? const [];
    final locale = Localizations.localeOf(context).toString();
    final favorite = ref.watch(favoriteProductProvider);

    if (MediaQuery.orientationOf(context) == Orientation.landscape) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 14, 16, 12),
            child: _ShakerWithLabels(
              shakerKey: _shakerKey,
              entries: entries,
              goal: goal,
              locale: locale,
              // The add button of the tab bar is close at hand.
              header: _Summary(
                dayKey: dayKey,
                entries: entries,
                goal: goal,
                locale: locale,
                favorite: favorite,
                onQuickAdd: _quickAdd,
                compact: true,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          // Lined up with the tab bar.
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Summary(
                dayKey: dayKey,
                entries: entries,
                goal: goal,
                locale: locale,
                favorite: favorite,
                onQuickAdd: _quickAdd,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _ShakerWithLabels(
                  shakerKey: _shakerKey,
                  entries: entries,
                  goal: goal,
                  locale: locale,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Date, goal, total, what is left, and the add button: the quick add of
/// the [favorite] if any, otherwise the form, which landscape leaves to the
/// tab bar.
class _Summary extends StatelessWidget {
  const _Summary({
    required this.dayKey,
    required this.entries,
    required this.goal,
    required this.locale,
    required this.favorite,
    required this.onQuickAdd,
    this.compact = false,
  });

  final int dayKey;
  final List<Entry> entries;
  final double goal;
  final String locale;
  final Product? favorite;
  final void Function(Product product, BuildContext button) onQuickAdd;

  /// Smaller, without the add button, for landscape.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colors = AppColors.of(context);
    String grams(double value) => formatGrams(value, locale);

    final total = entries.fold(0.0, (sum, entry) => sum + entry.proteinGrams);
    final reached = total >= goal;
    final status = textTheme.bodyLarge!.copyWith(
      fontSize: 14,
      color: colors.textSecondary,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          formatLongDate(dateOfDayKey(dayKey), locale),
          style: textTheme.headlineSmall!.copyWith(fontSize: compact ? 22 : 28),
        ),
        SizedBox(height: compact ? 4 : 10),
        Row(
          // The button sits on the status line, at the bottom of the block.
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                                fontSize: 26,
                              ),
                            ),
                          ],
                        ),
                        style: textTheme.displayLarge!.copyWith(
                          fontSize: compact ? 54 : 68,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.todayGoal(grams(goal)),
                    style: textTheme.bodyLarge!.copyWith(
                      fontSize: 15,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
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
                          // From the total as shown, truncated, so both agree.
                          TextSpan(
                            text: l10n.todayRemaining(
                              grams(goal - truncateGrams(total)),
                            ),
                          ),
                      ],
                    ),
                    style: status,
                  ),
                ],
              ),
            ),
            if (favorite case final favorite?) ...[
              const SizedBox(width: 12),
              QuickAddButton(
                product: favorite,
                locale: locale,
                onPressed: (button) => onQuickAdd(favorite, button),
              ),
            ] else if (!compact) ...[
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => context.push(AppRoutes.newEntry),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 64),
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: textTheme.labelLarge!.copyWith(fontSize: 19),
                ),
                icon: const Icon(LucideIcons.plus, size: 26),
                label: Text(l10n.addEntry),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// The shaker, as large as the screen allows, with a label per entry on
/// its right: the latest entry on top, like the layers.
class _ShakerWithLabels extends StatefulWidget {
  const _ShakerWithLabels({
    required this.shakerKey,
    required this.entries,
    required this.goal,
    required this.locale,
    this.header,
  });

  final GlobalKey shakerKey;
  final List<Entry> entries;
  final double goal;
  final String locale;

  /// Shown above the labels, next to the shaker.
  final Widget? header;

  @override
  State<_ShakerWithLabels> createState() => _ShakerWithLabelsState();
}

class _ShakerWithLabelsState extends State<_ShakerWithLabels> {
  final _scroll = ScrollController();

  /// Whether the labels overflow and scroll: only then is room kept on the
  /// right for the scrollbar.
  bool _scrollable = false;

  bool _onMetrics(ScrollMetricsNotification notification) {
    final scrollable = notification.metrics.maxScrollExtent > 0;
    if (scrollable != _scrollable) setState(() => _scrollable = scrollable);
    return false;
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final entries = widget.entries;
    final goal = widget.goal;
    final locale = widget.locale;
    final total = entries.fold(0.0, (sum, entry) => sum + entry.proteinGrams);

    return LayoutBuilder(
      builder: (context, constraints) {
        final shakerWidth = min(
          constraints.maxHeight * Shaker.aspectRatio,
          constraints.maxWidth * 0.5,
        );
        final bottomInset =
            shakerWidth / Shaker.aspectRatio * Shaker.bottomInset;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SizedBox(
              key: widget.shakerKey,
              width: shakerWidth,
              child: MotionShaker(
                layers: [
                  for (final entry in entries)
                    ShakerLayer(
                      grams: entry.proteinGrams,
                      slot: DaySlot.of(entry.createdAt),
                    ),
                ],
                goal: goal,
                semanticLabel: l10n.shakerDescription(
                  formatGrams(total, locale),
                  formatGrams(goal, locale),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.header case final header?) ...[
                    header,
                    const SizedBox(height: 12),
                  ],
                  Expanded(
                    // Sits at the bottom, next to the layers, while it fits; then
                    // scrolls with the latest entry kept on top.
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: NotificationListener<ScrollMetricsNotification>(
                        onNotification: _onMetrics,
                        child: RawScrollbar(
                          controller: _scroll,
                          thumbVisibility: true,
                          thickness: 4,
                          radius: const Radius.circular(2),
                          thumbColor: colors.structure,
                          child: ListView.separated(
                            controller: _scroll,
                            shrinkWrap: true,
                            padding: EdgeInsets.only(
                              bottom: bottomInset,
                              right: _scrollable ? 10 : 0,
                            ),
                            itemCount: entries.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 6),
                            itemBuilder: (context, index) => _EntryLabel(
                              entry: entries[entries.length - 1 - index],
                              locale: locale,
                            ),
                          ),
                        ),
                      ),
                    ),
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

class _EntryLabel extends StatelessWidget {
  const _EntryLabel({required this.entry, required this.locale});

  final Entry entry;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final name = entry.name;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => context.push(AppRoutes.editEntry(entry.id)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: AppColors.slot(DaySlot.of(entry.createdAt)),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name ?? l10n.unnamedEntry,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: name == null
                          ? textTheme.bodyMedium!.copyWith(
                              color: colors.textSecondary,
                              fontStyle: FontStyle.italic,
                            )
                          : textTheme.bodyMedium!.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                    ),
                    Text(
                      formatTime(entry.createdAt, locale),
                      style: textTheme.bodySmall!.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                l10n.grams(formatProtein(entry.proteinGrams, locale)),
                style: textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
