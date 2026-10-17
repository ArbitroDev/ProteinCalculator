import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/database/protein_amounts.dart';
import 'package:protein_calculator/core/formatting.dart';
import 'package:protein_calculator/core/theme.dart';
import 'package:protein_calculator/core/widgets/locale_name.dart';
import 'package:protein_calculator/l10n/app_localizations.dart';

/// Icon of creatine, wherever it shows: its card in the menu, its counter
/// in the forms, its button, the marks of the entries and products holding
/// it. Sparkles, like the powder.
const creatineIcon = LucideIcons.sparkles;

/// Name [entry] shows: its own, or that of creatine for creatine taken on
/// its own; null for an entry without a name.
String? shownEntryName(Entry entry, AppLocalizations l10n) =>
    entry.name ?? (entry.isCreatineOnly ? l10n.creatine : null);

/// Grams of [entry], in [style]: those of protein, or those of creatine for
/// creatine taken on its own, which screen readers tell.
class EntryGrams extends StatelessWidget {
  const EntryGrams({super.key, required this.entry, this.style});

  final Entry entry;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = context.localeName;
    if (!entry.isCreatineOnly) {
      return Text(
        l10n.grams(formatProtein(entry.proteinGrams, locale)),
        style: style,
      );
    }
    final grams = l10n.grams(formatProtein(entry.creatineGrams, locale));
    return Semantics(
      label: l10n.creatineGrams(grams),
      excludeSemantics: true,
      child: Text(grams, style: style),
    );
  }
}

/// Blue check of the days creatine was taken, [size] high, which screen
/// readers tell when [labelled].
class CreatineCheck extends StatelessWidget {
  const CreatineCheck({super.key, required this.size, this.labelled = false});

  final double size;
  final bool labelled;

  @override
  Widget build(BuildContext context) => Icon(
    LucideIcons.circleCheck,
    size: size,
    color: AppColors.of(context).creatineText,
    semanticLabel: labelled ? AppLocalizations.of(context).creatineTaken : null,
  );
}

/// Mark of an entry or a product holding creatine: its icon, and the number
/// of [doses] when there are several, which screen readers tell.
class CreatineMark extends StatelessWidget {
  const CreatineMark({
    super.key,
    required this.doses,
    this.size = 14,
    this.color,
  });

  final int doses;
  final double size;

  /// The blue of creatine by default; another one where it would not read,
  /// such as the colored cards of the parts of the day.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? AppColors.of(context).creatineText;
    return Semantics(
      label: AppLocalizations.of(context).creatineMark(doses),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(creatineIcon, size: size, color: color),
          if (doses > 1)
            Text(
              '×$doses',
              style: Theme.of(context).textTheme.labelSmall!.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
        ],
      ),
    );
  }
}
