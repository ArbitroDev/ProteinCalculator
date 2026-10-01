import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:protein_calculator/core/domain/grams.dart';
import 'package:protein_calculator/core/formatting.dart';
import 'package:protein_calculator/core/providers.dart';
import 'package:protein_calculator/core/router.dart';
import 'package:protein_calculator/core/theme.dart';
import 'package:protein_calculator/core/widgets/goal_field.dart';
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
  bool _showError = false;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final goal = parseDailyGoal(_controller.text);
    if (goal == null) {
      setState(() => _showError = true);
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
    final locale = Localizations.localeOf(context).toString();

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
                    goal: parseDailyGoal(_controller.text) ?? 140,
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
                style: textTheme.bodyLarge!.copyWith(
                  color: AppColors.of(context).textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              GoalField(
                controller: _controller,
                autofocus: true,
                showError: _showError,
                onChanged: (_) => setState(() => _showError = false),
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: Text(l10n.onboardingStart),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
