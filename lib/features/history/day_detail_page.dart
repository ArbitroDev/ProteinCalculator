import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
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
import 'package:protein_calculator/core/widgets/stacked_bar.dart';
import 'package:protein_calculator/core/widgets/undo_snack_bar.dart';
import 'package:protein_calculator/l10n/app_localizations.dart';

/// Entries of one day grouped by part of the day. Swiping an entry deletes
/// it, with a few seconds to undo.
class DayDetailPage extends ConsumerStatefulWidget {
  const DayDetailPage({super.key, required this.dayKey});

  final int dayKey;

  @override
  ConsumerState<DayDetailPage> createState() => _DayDetailPageState();
}

class _DayDetailPageState extends ConsumerState<DayDetailPage> {
  /// Entries swiped away, hidden until the database confirms the deletion.
  final _hidden = <int>{};

  Future<void> _delete(Entry entry) async {
    setState(() => _hidden.add(entry.id));
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final dao = ref.read(databaseProvider).entriesDao;

    final deleted = await dao.deleteEntry(entry.id);
    if (deleted == null) return;
    showUndoSnackBar(
      messenger,
      l10n: l10n,
      label: l10n.entryDeleted,
      onUndo: () async {
        await dao.restoreEntry(deleted);
        if (mounted) setState(() => _hidden.remove(entry.id));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toString();
    final goal = ref.watch(dailyGoalProvider).value ?? 0;
    final entries = [
      for (final entry
          in ref.watch(dayEntriesProvider(widget.dayKey)).value ?? <Entry>[])
        if (!_hidden.contains(entry.id)) entry,
    ];

    final bySlot = <DaySlot, List<Entry>>{};
    for (final entry in entries) {
      bySlot.putIfAbsent(DaySlot.of(entry.createdAt), () => []).add(entry);
    }
    double sum(Iterable<Entry> list) =>
        list.fold(0.0, (total, entry) => total + entry.proteinGrams);
    final total = sum(entries);
    final reached = goal > 0 && total >= goal;
    String grams(double value) => l10n.grams(formatGrams(value, locale));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => context.pop(),
        ),
        title: Text(formatLongDate(dateOfDayKey(widget.dayKey), locale)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            children: [
              Text(grams(total), style: textTheme.displayMedium),
              if (reached)
                Row(
                  mainAxisSize: MainAxisSize.min,
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
                Text(
                  l10n.dayGoalOf(formatGrams(goal, locale)),
                  style: textTheme.bodyLarge!.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          StackedBar(
            bySlot: {
              for (final MapEntry(key: slot, value: list) in bySlot.entries)
                slot: sum(list),
            },
            goal: goal,
          ),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 32),
              child: Text(
                l10n.dayEmpty,
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge!.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
          for (final slot in DaySlot.values)
            if (bySlot[slot] case final list?) ...[
              _SlotHeader(slot: slot, total: grams(sum(list))),
              for (final entry in list)
                _DismissibleEntry(
                  entry: entry,
                  grams: grams(entry.proteinGrams),
                  time: formatTime(entry.createdAt, locale),
                  onDelete: () => _delete(entry),
                ),
            ],
        ],
      ),
    );
  }
}

class _SlotHeader extends StatelessWidget {
  const _SlotHeader({required this.slot, required this.total});

  final DaySlot slot;
  final String total;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final label = switch (slot) {
      DaySlot.morning => l10n.slotMorning,
      DaySlot.afternoon => l10n.slotAfternoon,
      DaySlot.evening => l10n.slotEvening,
    };
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 4),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: AppColors.slot(slot),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: textTheme.titleSmall)),
          Text(total, style: textTheme.bodySmall!.copyWith(fontSize: 13)),
        ],
      ),
    );
  }
}

class _DismissibleEntry extends StatelessWidget {
  const _DismissibleEntry({
    required this.entry,
    required this.grams,
    required this.time,
    required this.onDelete,
  });

  final Entry entry;
  final String grams;
  final String time;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      customSemanticsActions: {
        CustomSemanticsAction(label: l10n.delete): onDelete,
      },
      child: Dismissible(
        key: ValueKey(entry.id),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => onDelete(),
        background: Container(
          color: AppColors.danger,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 22),
          child: const Icon(LucideIcons.trash2, color: Colors.white),
        ),
        child: Material(
          color: colors.background,
          child: InkWell(
            onTap: () => context.push(AppRoutes.editEntry(entry.id)),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: colors.divider)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: entry.name ?? l10n.unnamedEntry,
                        style: entry.name == null
                            ? textTheme.bodyLarge!.copyWith(
                                color: colors.textSecondary,
                                fontStyle: FontStyle.italic,
                              )
                            : textTheme.bodyLarge,
                        children: [
                          TextSpan(text: '  $time', style: textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ),
                  Text(grams, style: textTheme.titleMedium),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
