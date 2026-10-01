import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:protein_calculator/core/domain/grams.dart';
import 'package:protein_calculator/core/formatting.dart';
import 'package:protein_calculator/core/providers.dart';
import 'package:protein_calculator/core/router.dart';
import 'package:protein_calculator/core/theme.dart';
import 'package:protein_calculator/core/widgets/shaker.dart';
import 'package:protein_calculator/l10n/app_localizations.dart';

/// First launch screen: asks for the daily protein goal.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _controller = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double? get _validGoal {
    final goal = parseGrams(_controller.text);
    if (goal == null || goal < minDailyGoal || goal > maxDailyGoal) {
      return null;
    }
    return goal;
  }

  Future<void> _save() async {
    final goal = _validGoal;
    if (goal == null) {
      final locale = Localizations.localeOf(context).toString();
      setState(
        () => _error = AppLocalizations.of(context).goalInvalid(
          formatGrams(minDailyGoal, locale),
          formatGrams(maxDailyGoal, locale),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    await ref.read(databaseProvider).settingsDao.setDailyGoal(goal);
    if (mounted) context.go(AppRoutes.today);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colors = AppColors.of(context);
    final locale = Localizations.localeOf(context).toString();
    const underline = UnderlineInputBorder(
      borderSide: BorderSide(color: AppColors.accent, width: 2),
    );

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: SizedBox(
                  width: 78,
                  child: Shaker(
                    layers: const [],
                    goal: _validGoal ?? 140,
                    semanticLabel: '',
                    formatGrams: (grams) => formatGrams(grams, locale),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.onboardingTitle,
                style: textTheme.headlineSmall!.copyWith(fontSize: 26),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.onboardingBody,
                style: textTheme.bodyMedium!.copyWith(
                  color: colors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _controller,
                autofocus: true,
                textAlign: TextAlign.center,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() => _error = null),
                onSubmitted: (_) => _save(),
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
                  errorText: _error,
                  enabledBorder: underline,
                  focusedBorder: underline,
                  errorBorder: underline,
                  focusedErrorBorder: underline,
                ),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(l10n.onboardingStart),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
