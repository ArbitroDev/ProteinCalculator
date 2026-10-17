import 'package:flutter/material.dart';
import 'package:protein_calculator/core/domain/grams.dart';
import 'package:protein_calculator/core/formatting.dart';
import 'package:protein_calculator/core/theme.dart';
import 'package:protein_calculator/core/widgets/grams_input_formatter.dart';
import 'package:protein_calculator/core/widgets/locale_name.dart';
import 'package:protein_calculator/l10n/app_localizations.dart';

/// Large field to type the daily goal in grams, underlined in orange; also
/// used for other amounts of grams, given their [hint] and [error].
class GoalField extends StatelessWidget {
  const GoalField({
    super.key,
    required this.controller,
    required this.showError,
    required this.onChanged,
    required this.onSubmitted,
    this.autofocus = false,
    this.hint = '140',
    this.error,
    this.decimal = false,
  });

  final TextEditingController controller;

  /// Shows the [error] under the field, by default "between 1 and 1000".
  final bool showError;
  final String hint;
  final String? error;

  /// Allows one decimal, as for a creatine dose; the goal takes none.
  final bool decimal;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colors = AppColors.of(context);
    final locale = context.localeName;
    const underline = UnderlineInputBorder(
      borderSide: BorderSide(color: AppColors.accent, width: 2),
    );

    return TextField(
      controller: controller,
      autofocus: autofocus,
      textAlign: TextAlign.center,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      inputFormatters: [GramsInputFormatter(maxDecimals: decimal ? 1 : 0)],
      textInputAction: TextInputAction.done,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: textTheme.displayLarge!.copyWith(fontSize: 56),
      decoration: InputDecoration(
        filled: false,
        hintText: hint,
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
            ? error ??
                  l10n.goalInvalid(
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
