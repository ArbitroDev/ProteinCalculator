import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:protein_calculator/core/crash_reporting.dart';
import 'package:protein_calculator/core/domain/grams.dart';
import 'package:protein_calculator/core/providers.dart';
import 'package:protein_calculator/core/router.dart';
import 'package:protein_calculator/core/theme.dart';
import 'package:protein_calculator/core/widgets/goal_field.dart';
import 'package:protein_calculator/core/widgets/shaker.dart';
import 'package:protein_calculator/core/widgets/content_width.dart';
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

  /// Crash reports are off until the user checks the box.
  bool _crashReports = false;

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
    final settings = ref.read(databaseProvider).settingsDao;
    await settings.setDailyGoal(goal);
    if (crashReportingAvailable) {
      await settings.setCrashReports(_crashReports);
      await setCrashReporting(_crashReports);
    }
    if (mounted) context.go(AppRoutes.today);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: ContentWidth(
        child: SafeArea(
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
                if (crashReportingAvailable) ...[
                  const SizedBox(height: 18),
                  _CrashReportsChoice(
                    value: _crashReports,
                    onChanged: (value) => setState(() => _crashReports = value),
                  ),
                ],
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
      ),
    );
  }
}

class _CrashReportsChoice extends StatelessWidget {
  const _CrashReportsChoice({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colors = AppColors.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => onChanged(!value),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: value,
            onChanged: (checked) => onChanged(checked ?? false),
            activeColor: AppColors.accent,
            checkColor: AppColors.onAccent,
            side: BorderSide(color: colors.textSecondary, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.onboardingCrashReports, style: textTheme.bodyLarge),
                  const SizedBox(height: 2),
                  Text(
                    l10n.onboardingCrashReportsHint,
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
