import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:protein_calculator/core/crash_reporting.dart';
import 'package:protein_calculator/core/domain/day_slot.dart';
import 'package:protein_calculator/core/domain/grams.dart';
import 'package:protein_calculator/core/providers.dart';
import 'package:protein_calculator/core/router.dart';
import 'package:protein_calculator/core/theme.dart';
import 'package:protein_calculator/core/widgets/content_width.dart';
import 'package:protein_calculator/core/widgets/goal_field.dart';
import 'package:protein_calculator/core/widgets/shaker.dart';
import 'package:protein_calculator/core/widgets/user_action.dart';
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
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    setState(() => _saving = true);
    final settings = ref.read(databaseProvider).settingsDao;
    final saved = await runUserAction(messenger, l10n, () async {
      await settings.setDailyGoal(goal);
      if (crashReportingAvailable) {
        await settings.setCrashReports(_crashReports);
      }
      return true;
    });
    if (saved == null) {
      if (mounted) setState(() => _saving = false);
      return;
    }
    if (crashReportingAvailable) await setCrashReporting(_crashReports);
    if (mounted) context.go(AppRoutes.today);
  }

  /// Top of the shaker graduations on this screen.
  static const _shakerMax = 200.0;
  static const _shakerWidth = 96.0;

  /// Goal being typed, as grams for the shaker (0 while invalid).
  double get _typedGoal =>
      (int.tryParse(_controller.text.trim()) ?? 0).toDouble();

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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      // On two lines, the last word below, to stand beside
                      // the shaker, lined up with the top of its handle.
                      child: Padding(
                        padding: EdgeInsets.only(
                          top:
                              _shakerWidth /
                              Shaker.aspectRatio *
                              Shaker.topInset,
                        ),
                        child: Text(
                          l10n.onboardingTitle.replaceFirst(
                            RegExp(r' (?=\S+$)'),
                            '\n',
                          ),
                          style: textTheme.headlineSmall!.copyWith(
                            fontSize: 30,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Fills up to the typed goal, on fixed graduations from
                    // 0 to 200 g; above, it stays full.
                    SizedBox(
                      width: _shakerWidth,
                      child: Shaker(
                        layers: [
                          if (_typedGoal > 0)
                            ShakerLayer(
                              grams: _typedGoal,
                              slot: DaySlot.afternoon,
                            ),
                        ],
                        goal: _typedGoal,
                        maxGrams: _shakerMax,
                        showGoalLine: false,
                        semanticLabel: '',
                      ),
                    ),
                  ],
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
    final titleStyle = textTheme.bodyLarge!;
    // Height of the first line of the title, so the box can be centered on
    // it whatever the text size chosen on the phone.
    final line = TextPainter(
      text: TextSpan(text: l10n.onboardingCrashReports, style: titleStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final lineHeight = line.height;
    line.dispose();

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The box itself sits on the left edge, like the other fields:
            // its larger tap area overflows, the whole row being tappable.
            SizedBox(
              width: 18,
              height: lineHeight,
              child: Center(
                child: SizedBox.square(
                  dimension: 18,
                  child: OverflowBox(
                    maxWidth: 40,
                    maxHeight: 40,
                    child: Checkbox(
                      value: value,
                      onChanged: (checked) => onChanged(checked ?? false),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.onboardingCrashReports, style: titleStyle),
                  const SizedBox(height: 2),
                  Text(
                    l10n.onboardingCrashReportsHint,
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
