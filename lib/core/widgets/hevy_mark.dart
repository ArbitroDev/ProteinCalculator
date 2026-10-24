import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:protein_calculator/core/theme.dart';
import 'package:protein_calculator/l10n/app_localizations.dart';

/// Icon of the Hevy workouts, wherever it shows: the days holding one in the
/// calendar and the history, the filter, the menu card. A dumbbell, not the
/// logo of Hevy.
const hevyIcon = LucideIcons.dumbbell;

/// Dumbbell of the days with a Hevy workout, [size] high, which screen
/// readers tell when [labelled].
class HevyMark extends StatelessWidget {
  const HevyMark({super.key, required this.size, this.labelled = false});

  final double size;
  final bool labelled;

  @override
  Widget build(BuildContext context) => Icon(
    hevyIcon,
    size: size,
    color: AppColors.of(context).hevy,
    semanticLabel: labelled ? AppLocalizations.of(context).hevyWorkout : null,
  );
}
