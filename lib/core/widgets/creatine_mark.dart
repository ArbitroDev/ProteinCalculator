import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:protein_calculator/core/theme.dart';
import 'package:protein_calculator/l10n/app_localizations.dart';

/// Icon of creatine, wherever it shows: its card in the menu, its counter
/// in the forms, its button, the marks of the entries and products holding
/// it. Sparkles, like the powder.
const creatineIcon = LucideIcons.sparkles;

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
