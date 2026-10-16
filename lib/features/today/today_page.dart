import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/database/protein_amounts.dart';
import 'package:protein_calculator/core/domain/app_day.dart';
import 'package:protein_calculator/core/domain/day_slot.dart';
import 'package:protein_calculator/core/formatting.dart';
import 'package:protein_calculator/core/providers.dart';
import 'package:protein_calculator/core/router.dart';
import 'package:protein_calculator/core/theme.dart';
import 'package:protein_calculator/core/widgets/locale_name.dart';
import 'package:protein_calculator/core/widgets/motion_shaker.dart';
import 'package:protein_calculator/core/widgets/shaker.dart';
import 'package:protein_calculator/core/widgets/swipe_to_delete.dart';
import 'package:protein_calculator/core/widgets/undo_snack_bar.dart';
import 'package:protein_calculator/core/widgets/user_action.dart';
import 'package:protein_calculator/features/today/quick_add.dart';
import 'package:protein_calculator/l10n/app_localizations.dart';

/// Main tab: the summary of the current app day, then the shaker with one
/// label per entry next to it, swiped to the left to delete the entry. In
/// landscape, the shaker stands on the left and the summary tops the labels.
class TodayPage extends ConsumerStatefulWidget {
  const TodayPage({super.key});

  @override
  ConsumerState<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends ConsumerState<TodayPage> with UndoableDeletion {
  /// Where the quick added favorite falls.
  final _shakerKey = GlobalKey();

  /// Adds the favorite without the form: a drop flies from where the button
  /// was touched, [from], into the shaker, then the entry lands, with a few
  /// seconds to undo.
  Future<void> _quickAdd(Product product, Offset from) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final entries = ref.read(databaseProvider).entriesDao;
    if (!MediaQuery.disableAnimationsOf(context)) {
      await flyToShaker(
        context,
        from: from,
        shaker: _shakerKey,
        color: AppColors.slot(DaySlot.of(ref.read(clockProvider)())),
      );
    }
    final id = await runUserAction(
      messenger,
      l10n,
      () => entries.addPortion(product, createdAt: ref.read(clockProvider)()),
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

  Future<void> _delete(Entry entry) {
    final dao = ref.read(databaseProvider).entriesDao;
    return deleteWithUndo(
      id: entry.id,
      delete: () => dao.deleteEntry(entry.id),
      restore: dao.restoreEntry,
      label: AppLocalizations.of(context).entryDeleted,
    );
  }

  @override
  Widget build(BuildContext context) {
    final dayKey = ref.watch(currentDayKeyProvider).value;
    final goal = ref.watch(dailyGoalProvider).value;
    if (dayKey == null || goal == null) return const Scaffold();
    final entries = [
      for (final entry
          in ref.watch(dayEntriesProvider(dayKey)).value ?? const <Entry>[])
        if (!isDeleted(entry.id)) entry,
    ];
    final locale = context.localeName;
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
              onDelete: _delete,
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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
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
              // Keeps the shaker at its size, the labels at their width: the
              // room the summary gave up stays above the shaker.
              const SizedBox(height: 30),
              Expanded(
                child: _ShakerWithLabels(
                  shakerKey: _shakerKey,
                  entries: entries,
                  goal: goal,
                  locale: locale,
                  onDelete: _delete,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Date, total and goal, what is left, and under them the add button: the
/// quick add of the [favorite] if any, otherwise the form, which landscape
/// leaves to the tab bar.
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
  final void Function(Product product, Offset from) onQuickAdd;

  /// Smaller, without the add button, for landscape.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colors = AppColors.of(context);
    String grams(double value) => formatGrams(value, locale);

    final total = entries.proteinGrams;
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
          style: textTheme.headlineSmall!.copyWith(fontSize: compact ? 21 : 26),
        ),
        SizedBox(height: compact ? 4 : 10),
        ExcludeSemantics(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            // The total, orange once the goal is reached, then the
            // goal, smaller and lighter: 120 g / 140 g.
            child: Text.rich(
              TextSpan(
                text: grams(total),
                children: [
                  TextSpan(
                    text: ' ${l10n.gramsUnit}',
                    style: textTheme.displayLarge!.copyWith(
                      fontSize: 26,
                      color: reached ? colors.accentText : null,
                    ),
                  ),
                  TextSpan(
                    text: ' / ${grams(goal)}',
                    style: textTheme.displayLarge!.copyWith(
                      fontSize: compact ? 28 : 34,
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary,
                    ),
                  ),
                  TextSpan(
                    text: ' ${l10n.gramsUnit}',
                    style: textTheme.displayLarge!.copyWith(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
              style: textTheme.displayLarge!.copyWith(
                fontSize: compact ? 54 : 68,
                color: reached ? colors.accentText : null,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
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
                  text: l10n.todayRemaining(grams(goal - truncateGrams(total))),
                ),
            ],
          ),
          style: status,
        ),
        // The add button under the summary, as wide as its content, so the
        // total keeps its room: the quick add of the favorite, or else the form,
        // which landscape leaves to the tab bar.
        if (favorite case final favorite?) ...[
          SizedBox(height: compact ? 8 : 12),
          QuickAddButton(
            product: favorite,
            locale: locale,
            onPressed: (from) => onQuickAdd(favorite, from),
          ),
        ] else if (!compact) ...[
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => context.push(AppRoutes.newEntry),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 52),
              padding: const EdgeInsets.fromLTRB(14, 10, 18, 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: textTheme.labelLarge!.copyWith(fontSize: 16),
            ),
            icon: const Icon(LucideIcons.plus, size: 24),
            label: Text(l10n.addEntry),
          ),
        ],
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
    required this.onDelete,
    this.header,
  });

  final GlobalKey shakerKey;
  final List<Entry> entries;
  final double goal;
  final String locale;
  final void Function(Entry entry) onDelete;

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
    final total = entries.proteinGrams;

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
                    ShakerLayer(grams: entry.proteinGrams, slot: entry.slot),
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
                            itemBuilder: (context, index) {
                              final entry = entries[entries.length - 1 - index];
                              return _EntryLabel(
                                entry: entry,
                                locale: locale,
                                onDelete: () => widget.onDelete(entry),
                              );
                            },
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
  const _EntryLabel({
    required this.entry,
    required this.locale,
    required this.onDelete,
  });

  final Entry entry;
  final String locale;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final name = entry.name;

    // Clipped, so the red background of the swipe keeps the rounded corners.
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SwipeToDelete(
        key: ValueKey(entry.id),
        onDelete: onDelete,
        // Square, like its highlight, which fills the corners when the
        // label slides; the clip above rounds both while it rests.
        child: Material(
          color: colors.surface,
          child: InkWell(
            onTap: () => context.push(AppRoutes.editEntry(entry.id)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              child: Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: AppColors.slot(entry.slot),
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
                        Row(
                          children: [
                            Text(
                              formatTime(entry.createdAt, locale),
                              style: textTheme.bodySmall!.copyWith(
                                fontSize: 11,
                              ),
                            ),
                            if (entry.fromWatch) ...[
                              const SizedBox(width: 4),
                              Icon(
                                LucideIcons.watch,
                                size: 11,
                                color: colors.textSecondary,
                                semanticLabel: l10n.entryFromWatch,
                              ),
                            ],
                          ],
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
        ),
      ),
    );
  }
}
