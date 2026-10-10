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
import 'package:protein_calculator/core/widgets/stacked_bar.dart';
import 'package:protein_calculator/core/widgets/swipe_to_delete.dart';
import 'package:protein_calculator/l10n/app_localizations.dart';

/// Entries of one day on stacked cards, one per part of the day. Swiping an
/// entry deletes it, with a few seconds to undo.
class DayDetailPage extends ConsumerStatefulWidget {
  const DayDetailPage({super.key, required this.dayKey});

  final int dayKey;

  @override
  ConsumerState<DayDetailPage> createState() => _DayDetailPageState();
}

class _DayDetailPageState extends ConsumerState<DayDetailPage>
    with UndoableDeletion {
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
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final locale = context.localeName;
    final goal = ref.watch(dayGoalProvider(widget.dayKey)) ?? 0;
    final entries = [
      for (final entry
          in ref.watch(dayEntriesProvider(widget.dayKey)).value ?? <Entry>[])
        if (!isDeleted(entry.id)) entry,
    ];

    final bySlot = <DaySlot, List<Entry>>{};
    for (final entry in entries) {
      bySlot.putIfAbsent(entry.slot, () => []).add(entry);
    }
    final slots = [
      for (final slot in DaySlot.values)
        if (bySlot.containsKey(slot)) slot,
    ];
    final total = entries.proteinGrams;
    final reached = goal > 0 && total >= goal;
    String grams(double value) => l10n.grams(formatGrams(value, locale));

    final summary = [
      for (final header in [
        // The goal sits on the baseline of the total.
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(grams(total), style: textTheme.displayMedium),
            const SizedBox(width: 10),
            if (reached)
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Icon(
                    LucideIcons.circleCheck,
                    size: 18,
                    color: colors.accentText,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    l10n.todayGoalReached,
                    style: textTheme.bodyLarge!.copyWith(
                      color: colors.accentText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            else
              Flexible(
                child: Text(
                  l10n.dayGoalOf(formatGrams(goal, locale)),
                  style: textTheme.bodyLarge!.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        StackedBar(
          bySlot: {
            for (final MapEntry(key: slot, value: list) in bySlot.entries)
              slot: list.proteinGrams,
          },
          goal: goal,
        ),
      ])
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: header,
        ),
    ];
    final cards = [
      if (entries.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 32),
          child: Text(
            l10n.dayEmpty,
            textAlign: TextAlign.center,
            style: textTheme.bodyLarge!.copyWith(color: colors.textSecondary),
          ),
        ),
      if (slots.isNotEmpty) const SizedBox(height: 18),
      // Each card seems to slide over the bottom of the previous one, like
      // cards in a wallet.
      for (final (index, slot) in slots.indexed)
        _SlotCard(
          slot: slot,
          total: grams(bySlot[slot]!.proteinGrams),
          previous: index > 0 ? slots[index - 1] : null,
          coveredBelow: index < slots.length - 1,
          children: [
            for (final entry in bySlot[slot]!)
              _DismissibleEntry(
                entry: entry,
                color: AppColors.slot(slot),
                grams: l10n.grams(formatProtein(entry.proteinGrams, locale)),
                time: formatTime(entry.createdAt, locale),
                onDelete: () => _delete(entry),
              ),
          ],
        ),
    ];
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    return Scaffold(
      appBar: AppBar(
        title: Text(formatLongDate(dateOfDayKey(widget.dayKey), locale)),
      ),
      body: landscape
          // The summary on the left, the cards on the right.
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(6, 4, 6, 24),
                    children: summary,
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(6, 4, 6, 24),
                    children: cards,
                  ),
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 24),
              children: [...summary, ...cards],
            ),
    );
  }
}

/// Card of one part of the day, in the color of its entries.
///
/// The cards are laid out one after the other, without overlapping, so
/// every entry gets its taps: the wallet look comes from drawing, around
/// the rounded top corners of a card, the color of the [previous] one, whose
/// own bottom corners stay square.
class _SlotCard extends StatelessWidget {
  const _SlotCard({
    required this.slot,
    required this.total,
    required this.previous,
    required this.coveredBelow,
    required this.children,
  });

  final DaySlot slot;
  final String total;

  /// Part of the day of the card above, which seems to go on under this one.
  final DaySlot? previous;

  /// Whether the next card seems to cover the bottom of this one.
  final bool coveredBelow;
  final List<Widget> children;

  static const _radius = Radius.circular(20);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // The part of the day stands out more than its entries.
    final style = Theme.of(context).textTheme.headlineSmall!
        .copyWith(color: AppColors.onAccent, fontSize: 20);
    final (icon, label) = switch (slot) {
      DaySlot.morning => (LucideIcons.sunrise, l10n.slotMorning),
      DaySlot.afternoon => (LucideIcons.sun, l10n.slotAfternoon),
      DaySlot.evening => (LucideIcons.moon, l10n.slotEvening),
    };
    final card = Material(
      color: AppColors.slot(slot),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: _radius,
          bottom: coveredBelow ? Radius.zero : _radius,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: coveredBelow ? 12 : 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Row(
                children: [
                  Icon(icon, size: 22, color: AppColors.onAccent),
                  const SizedBox(width: 10),
                  Expanded(child: Text(label, style: style)),
                  Text(total, style: style),
                ],
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
    final previous = this.previous;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: previous == null
          ? card
          : Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: _radius.y,
                  child: ColoredBox(color: AppColors.slot(previous)),
                ),
                card,
              ],
            ),
    );
  }
}

class _DismissibleEntry extends StatelessWidget {
  const _DismissibleEntry({
    required this.entry,
    required this.color,
    required this.grams,
    required this.time,
    required this.onDelete,
  });

  final Entry entry;

  /// Color of the card the entry sits on.
  final Color color;
  final String grams;
  final String time;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    const ink = AppColors.onAccent;
    final faded = ink.withValues(alpha: 0.7);

    return SwipeToDelete(
      key: ValueKey(entry.id),
      onDelete: onDelete,
      child: Material(
        color: color,
        child: InkWell(
          onTap: () => context.push(AppRoutes.editEntry(entry.id)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: entry.name ?? l10n.unnamedEntry,
                      style: entry.name == null
                          ? textTheme.bodyMedium!.copyWith(
                              color: faded,
                              fontStyle: FontStyle.italic,
                            )
                          : textTheme.bodyMedium!.copyWith(color: ink),
                      children: [
                        TextSpan(
                          text: '  $time',
                          style: textTheme.bodySmall!.copyWith(color: faded),
                        ),
                      ],
                    ),
                  ),
                ),
                Text(
                  grams,
                  style: textTheme.bodyMedium!.copyWith(
                    color: ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
