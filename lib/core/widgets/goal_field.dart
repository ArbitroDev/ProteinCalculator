import 'package:flutter/material.dart';
import 'package:protein_calculator/core/domain/grams.dart';
import 'package:protein_calculator/core/formatting.dart';
import 'package:protein_calculator/core/theme.dart';
import 'package:protein_calculator/core/widgets/grams_input_formatter.dart';
import 'package:protein_calculator/l10n/app_localizations.dart';

/// Large field to type the daily goal in grams, underlined in orange.
class GoalField extends StatelessWidget {
  const GoalField({
    super.key,
    required this.controller,
    required this.showError,
    required this.onChanged,
    required this.onSubmitted,
    this.autofocus = false,
  });

  final TextEditingController controller;

  /// Shows the "between 1 and 1000" error under the field.
  final bool showError;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colors = AppColors.of(context);
    final locale = Localizations.localeOf(context).toString();
    const underline = UnderlineInputBorder(
      borderSide: BorderSide(color: AppColors.accent, width: 2),
    );

    return TextField(
      controller: controller,
      autofocus: autofocus,
      textAlign: TextAlign.center,
      keyboardType: TextInputType.number,
      inputFormatters: [GramsInputFormatter()],
      textInputAction: TextInputAction.done,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: textTheme.displayLarge!.copyWith(fontSize: 56),
      decoration: InputDecoration(
        filled: false,
        hintText: '140',
        hintStyle: textTheme.displayLarge!.copyWith(
          fontSize: 56,
          color: colors.textSecondary.withValues(alpha: 0.4),
        ),
        suffixText: l10n.gramsUnit,
        suffixStyle: textTheme.titleMedium!.copyWith(
          fontSize: 22,
          color: colors.textSecondary,
        ),
        errorText: showError
            ? l10n.goalInvalid(
                formatGrams(minDailyGoal, locale),
                formatGrams(maxDailyGoal, locale),
              )
            : null,
        enabledBorder: underline,
        focusedBorder: underline,
        errorBorder: underline,
        focusedErrorBorder: underline,
      ),
    );
  }
}
