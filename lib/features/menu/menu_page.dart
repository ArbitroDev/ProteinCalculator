import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:protein_calculator/core/daily_routines.dart';
import 'package:protein_calculator/core/domain/app_day.dart';
import 'package:protein_calculator/core/domain/creatine.dart';
import 'package:protein_calculator/core/domain/day_slot.dart';
import 'package:protein_calculator/core/domain/grams.dart';
import 'package:protein_calculator/core/domain/slot_reminder.dart';
import 'package:protein_calculator/core/formatting.dart';
import 'package:protein_calculator/core/hevy/hevy_import_flow.dart';
import 'package:protein_calculator/core/providers.dart';
import 'package:protein_calculator/core/router.dart';
import 'package:protein_calculator/core/theme.dart';
import 'package:protein_calculator/core/widgets/content_width.dart';
import 'package:protein_calculator/core/widgets/creatine_mark.dart';
import 'package:protein_calculator/core/widgets/goal_field.dart';
import 'package:protein_calculator/core/widgets/hevy_mark.dart';
import 'package:protein_calculator/core/widgets/locale_name.dart';
import 'package:protein_calculator/core/widgets/notifications_off.dart';
import 'package:protein_calculator/core/widgets/shaker_icon.dart';
import 'package:protein_calculator/core/widgets/user_action.dart';
import 'package:protein_calculator/l10n/app_localizations.dart';

/// Menu tab: daily goal, start of the day, reminders, privacy, licenses and
/// about.
class MenuPage extends ConsumerWidget {
  const MenuPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final locale = context.localeName;
    final goal = ref.watch(dailyGoalProvider).value;
    final startHour = ref.watch(dayStartHourProvider).value;
    final version = ref.watch(appVersionProvider).value;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabMenu)),
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
          children: [
            Material(
              color: colors.surface,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: goal == null ? null : () => _editGoal(context, goal),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // The protein shaker, as creatine has its sparkles.
                      IconTheme(
                        data: IconThemeData(size: 24, color: colors.accentText),
                        child: const ShakerIcon(),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.menuGoal, style: textTheme.bodySmall),
                            Text(
                              goal == null
                                  ? ''
                                  : l10n.grams(formatGrams(goal, locale)),
                              style: textTheme.displaySmall!.copyWith(
                                fontSize: 36,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        l10n.edit,
                        style: textTheme.bodyLarge!.copyWith(
                          color: colors.accentText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const _CreatineCard(),
            const SizedBox(height: 10),
            const _HevyCard(),
            const SizedBox(height: 10),
            Material(
              color: colors.surface,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: startHour == null
                    ? null
                    : () => _editStartHour(context, startHour),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.menuDayStart, style: textTheme.bodySmall),
                            Text(
                              startHour == null
                                  ? ''
                                  : formatTime(
                                      DateTime(2000, 1, 1, startHour),
                                      locale,
                                    ),
                              style: textTheme.displaySmall!.copyWith(
                                fontSize: 24,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        l10n.edit,
                        style: textTheme.bodyLarge!.copyWith(
                          color: colors.accentText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const _SlotRemindersCard(),
            const SizedBox(height: 16),
            _MenuItem(
              icon: LucideIcons.shieldCheck,
              label: l10n.menuPrivacy,
              onTap: () => context.go(AppRoutes.dataPrivacy),
            ),
            _MenuItem(
              icon: LucideIcons.fileText,
              label: l10n.menuLicenses,
              onTap: () => showLicensePage(
                context: context,
                applicationName: l10n.appTitle,
                applicationVersion: version,
                applicationLegalese: l10n.licensesExplanation,
              ),
            ),
            _MenuItem(
              icon: LucideIcons.info,
              label: l10n.menuAbout,
              onTap: () => context.go(AppRoutes.about),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editGoal(BuildContext context, double goal) =>
      _showSheet(context, _GoalSheet(goal: goal));
}

Future<void> _editStartHour(BuildContext context, int hour) =>
    _showSheet(context, _StartHourSheet(hour: hour));

Future<void> _editCreatineDose(BuildContext context, double grams) =>
    _showSheet(context, _CreatineDoseSheet(grams: grams));

Future<void> _showHevy(BuildContext context) =>
    _showSheet(context, const _HevySheet());

/// Lets the user pick a Hevy export, then imports it, from the card of the
/// menu or its sheet.
Future<void> _importHevyFile(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context);
  final clock = ref.read(clockProvider);
  final content = await runUserAction(
    messenger,
    l10n,
    () => pickHevyFile(messenger, l10n),
  );
  if (content == null || !context.mounted) return;
  await runHevyImport(
    context: context,
    db: ref.read(databaseProvider),
    messenger: messenger,
    l10n: l10n,
    firstDayKey: ref.read(firstAppDayKeyProvider),
    todayKey: ref.read(currentDayKeyProvider).value ?? dayKeyOf(clock()),
    content: content,
    clock: clock,
  );
}

/// Shows [sheet] at the bottom of the screen, over the tab bar, which would
/// otherwise stay around it and take taps, and as tall as its content,
/// which scrolls on short screens.
Future<void> _showSheet(BuildContext context, Widget sheet) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      // Its color and shape come from the theme, read again when it changes
      // while the sheet is open.
      // The safe area of the sheet leaves its bottom to it: its content
      // keeps clear of the Android navigation bar, the sheet itself going
      // under it.
      builder: (context) => SafeArea(top: false, child: sheet),
    );

/// Switch of creatine tracking, with the grams of one dose, edited with a
/// tap once it is on.
class _CreatineCard extends ConsumerWidget {
  const _CreatineCard();

  /// Turns creatine on, the first time asking for the dose at once, or off.
  Future<void> _set(BuildContext context, WidgetRef ref, bool enabled) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final settings = ref.read(databaseProvider).settingsDao;
    final first = !(await settings.getCreatine()).everEnabled;
    final saved = await runUserAction(messenger, l10n, () async {
      await settings.setCreatineEnabled(enabled);
      return true;
    });
    if (enabled && first && saved != null && context.mounted) {
      await _editCreatineDose(context, defaultCreatineDoseGrams);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final locale = context.localeName;
    final creatine = ref.watch(creatineSettingsProvider).value;
    final dose = creatine?.doseGrams;
    final enabled = creatine?.enabled ?? false;

    // A tap anywhere turns creatine on, then edits the dose, as the edit
    // button does, set apart from the switch by a line.
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(14),
      child: ListTile(
        onTap: creatine == null
            ? null
            : enabled && dose != null
            ? () => _editCreatineDose(context, dose)
            : () => _set(context, ref, true),
        leading: Icon(creatineIcon, size: 22, color: colors.creatineText),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
        title: Text(
          l10n.creatine,
          style: textTheme.bodyLarge!.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          enabled && dose != null
              ? l10n.menuCreatineDose(l10n.grams(formatProtein(dose, locale)))
              : l10n.menuCreatineOff,
          style: textTheme.bodySmall!.copyWith(color: colors.textSecondary),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: enabled && dose != null
                  ? () => _editCreatineDose(context, dose)
                  : null,
              // As wide as its text, close to the line.
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.only(left: 12, right: 5),
              ),
              child: Text(l10n.edit),
            ),
            const SizedBox(width: 6),
            Container(width: 1, height: 28, color: colors.divider),
            const SizedBox(width: 10),
            // Named by the card for screen readers.
            Semantics(
              label: l10n.creatine,
              child: Switch(
                value: enabled,
                onChanged: creatine == null
                    ? null
                    : (value) => _set(context, ref, value),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet editing the grams of one creatine dose.
class _CreatineDoseSheet extends ConsumerStatefulWidget {
  const _CreatineDoseSheet({required this.grams});

  final double grams;

  @override
  ConsumerState<_CreatineDoseSheet> createState() => _CreatineDoseSheetState();
}

class _CreatineDoseSheetState extends ConsumerState<_CreatineDoseSheet> {
  late final _controller = TextEditingController(
    text: formatProtein(widget.grams, context.localeName),
  );
  bool _showError = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final grams = parseGrams(_controller.text);
    if (grams == null || !isValidCreatineDoseGrams(grams)) {
      setState(() => _showError = true);
      return;
    }
    await runUserAction(
      ScaffoldMessenger.of(context),
      AppLocalizations.of(context),
      () => ref.read(databaseProvider).settingsDao.setCreatineDoseGrams(grams),
    );
    // Closed even on failure: the message shows under the sheet otherwise.
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final locale = context.localeName;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        22,
        22,
        22,
        18 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.creatineDoseTitle, style: textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            l10n.creatineDoseBody,
            style: textTheme.bodyLarge!.copyWith(
              color: AppColors.of(context).textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          GoalField(
            controller: _controller,
            autofocus: true,
            showError: _showError,
            hint: formatProtein(defaultCreatineDoseGrams, locale),
            decimal: true,
            error: l10n.creatineDoseInvalid(
              formatGrams(minCreatineDoseGrams, locale),
              formatGrams(maxCreatineDoseGrams, locale),
            ),
            onChanged: (_) => setState(() => _showError = false),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }
}

/// Card opening the Hevy sheet, with what was imported once something was,
/// and importing a file at once from its button. Always there, even while
/// nothing is imported: it is the way in.
class _HevyCard extends ConsumerStatefulWidget {
  const _HevyCard();

  @override
  ConsumerState<_HevyCard> createState() => _HevyCardState();
}

class _HevyCardState extends ConsumerState<_HevyCard> {
  /// Whether a file is being chosen or imported: the button waits.
  bool _busy = false;

  Future<void> _import() async {
    setState(() => _busy = true);
    try {
      await _importHevyFile(context, ref);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final importedAt = ref.watch(hevyImportedAtProvider).value;
    final days = ref.watch(shownHevyDaysProvider).length;

    // A tap anywhere shows what is imported; the import button, set apart by
    // a line, picks a file at once.
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(14),
      child: ListTile(
        onTap: () => _showHevy(context),
        leading: const HevyMark(size: 22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
        title: Text(
          l10n.menuHevy,
          style: textTheme.bodyLarge!.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          importedAt == null
              ? l10n.menuHevyNone
              : l10n.menuHevySummary(
                  l10n.hevyDays(days),
                  formatDayMonth(
                    importedAt,
                    context.localeName,
                    now: ref.read(clockProvider)(),
                  ),
                ),
          style: textTheme.bodySmall!.copyWith(color: colors.textSecondary),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 1, height: 28, color: colors.divider),
            const SizedBox(width: 6),
            TextButton(
              onPressed: _busy ? null : _import,
              // As wide as its text, close to the edge of the card.
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.only(left: 12, right: 4),
              ),
              child: Text(l10n.menuHevyImport),
            ),
          ],
        ),
      ),
    );
  }
}

/// When the latest Hevy workout starts, read again after each import.
final _lastHevyStartProvider = FutureProvider.autoDispose<DateTime?>((ref) {
  ref.watch(hevyImportedAtProvider);
  return ref.watch(databaseProvider).hevyDao.getLastSessionStart();
});

/// Bottom sheet importing the Hevy workouts from an export, telling what is
/// imported and deleting it. It stays open through an import and follows it.
class _HevySheet extends ConsumerStatefulWidget {
  const _HevySheet();

  @override
  ConsumerState<_HevySheet> createState() => _HevySheetState();
}

class _HevySheetState extends ConsumerState<_HevySheet> {
  /// Whether a file is being chosen or imported: its buttons wait.
  bool _busy = false;

  Future<void> _pickFile() async {
    setState(() => _busy = true);
    try {
      await _importHevyFile(context, ref);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clear() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.hevyClearTitle),
        content: Text(l10n.hevyClearBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.hevyClearConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await runUserAction(
      messenger,
      l10n,
      () => ref.read(databaseProvider).hevyDao.clear(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final locale = context.localeName;
    final now = ref.read(clockProvider)();
    final importedAt = ref.watch(hevyImportedAtProvider).value;
    final days = ref.watch(shownHevyDaysProvider).length;
    final lastStart = importedAt == null
        ? null
        : ref.watch(_lastHevyStartProvider).value;

    return Stack(
      children: [
        SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const HevyMark(size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.menuHevy,
                        style: textTheme.headlineSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (importedAt != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.hevyDays(days),
                          style: textTheme.bodyLarge!.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (lastStart != null)
                          Text(
                            l10n.hevyLastWorkout(
                              formatDayMonth(lastStart, locale, now: now),
                            ),
                            style: textTheme.bodyMedium,
                          ),
                        Text(
                          l10n.hevyImportedOn(
                            formatDayMonth(importedAt, locale, now: now),
                          ),
                          style: textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                Text(l10n.hevyHowTo, style: textTheme.bodyLarge),
                const SizedBox(height: 10),
                Text(
                  l10n.hevyPrivacyNote,
                  style: textTheme.bodyLarge!.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : _pickFile,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: Text(l10n.hevyPickFile),
                ),
                if (importedAt != null) ...[
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: _busy ? null : _clear,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: Text(l10n.hevyClear),
                  ),
                ],
                const SizedBox(height: 14),
                Text(
                  l10n.hevyTrademark,
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall!.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        // The sheet hides the messages of the page behind it: this scaffold
        // gives them a place over the sheet, where the user looks.
        const Positioned.fill(
          child: IgnorePointer(
            child: Scaffold(backgroundColor: Colors.transparent),
          ),
        ),
      ],
    );
  }
}

/// Switch of the reminders of the parts of the day left empty, see
/// `SlotReminder`, with a banner when their notifications are off or late.
class _SlotRemindersCard extends ConsumerWidget {
  const _SlotRemindersCard();

  /// Turns the reminders on, asking to allow notifications first, as they
  /// are nothing else, then for exact times; or turns them off.
  Future<void> _set(BuildContext context, WidgetRef ref, bool enabled) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final settings = ref.read(databaseProvider).settingsDao;
    final status = ref.read(notificationStatusProvider.notifier);
    if (enabled && !await _shows(ref) && !await status.requestSlotReminders()) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.slotRemindersNeedNotifications),
          action: SnackBarAction(
            label: l10n.openSettings,
            onPressed: status.openSettings,
          ),
        ),
      );
      return;
    }
    final saved = await runUserAction(messenger, l10n, () async {
      await settings.setSlotReminders(enabled);
      return true;
    });
    if (enabled && saved != null && context.mounted) {
      await askExactAlarms(context, ref);
    }
  }

  /// Whether the reminders can show, once known: a switch turned on before
  /// would not ask for notifications. Assumed if it cannot be read.
  static Future<bool> _shows(WidgetRef ref) async {
    try {
      return (await ref.read(notificationStatusProvider.future))
          .showsSlotReminders;
    } on Object {
      return true;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final locale = context.localeName;
    final enabled = ref.watch(slotRemindersProvider).value;
    final notifications = ref.watch(notificationStatusProvider).value;
    String hour(DaySlot slot) =>
        formatTime(DateTime(2000, 1, 1, slotReminderHour(slot)), locale);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          child: SwitchListTile(
            value: enabled ?? false,
            onChanged: enabled == null
                ? null
                : (value) => _set(context, ref, value),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            contentPadding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
            title: Text(
              l10n.menuSlotReminders,
              style: textTheme.bodyLarge!.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              l10n.menuSlotRemindersBody(
                hour(DaySlot.morning),
                hour(DaySlot.afternoon),
                hour(DaySlot.evening),
              ),
              style: textTheme.bodySmall!.copyWith(color: colors.textSecondary),
            ),
          ),
        ),
        if ((enabled ?? false) && notifications != null)
          if (!notifications.showsSlotReminders)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: NotificationsOff(
                message: l10n.notificationsOffSlotReminders,
              ),
            )
          else if (!notifications.exact)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: NotificationsOff(
                message: l10n.slotRemindersMayBeLate,
                late: true,
              ),
            ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.divider)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: colors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyLarge!
                    .copyWith(fontSize: 16),
              ),
            ),
            Icon(
              LucideIcons.chevronRight,
              size: 18,
              color: colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet editing the daily goal.
class _GoalSheet extends ConsumerStatefulWidget {
  const _GoalSheet({required this.goal});

  final double goal;

  @override
  ConsumerState<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends ConsumerState<_GoalSheet> {
  late final _controller = TextEditingController(
    text: widget.goal.round().toString(),
  );
  bool _showError = false;

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
    await runUserAction(
      ScaffoldMessenger.of(context),
      AppLocalizations.of(context),
      () => ref
          .read(databaseProvider)
          .settingsDao
          .setDailyGoal(goal, now: ref.read(clockProvider)()),
    );
    // Closed even on failure: the message shows under the sheet otherwise.
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        22,
        22,
        22,
        18 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.menuGoal, style: textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            l10n.goalSheetBody,
            style: textTheme.bodyLarge!.copyWith(
              color: AppColors.of(context).textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          GoalField(
            controller: _controller,
            autofocus: true,
            showError: _showError,
            onChanged: (_) => setState(() => _showError = false),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet choosing the hour the app day, and its morning, start, on
/// a slider from midnight to 7 a.m.
class _StartHourSheet extends ConsumerStatefulWidget {
  const _StartHourSheet({required this.hour});

  final int hour;

  @override
  ConsumerState<_StartHourSheet> createState() => _StartHourSheetState();
}

class _StartHourSheetState extends ConsumerState<_StartHourSheet> {
  late int _hour = widget.hour;

  Future<void> _save() async {
    if (_hour != widget.hour) {
      await runUserAction(
        ScaffoldMessenger.of(context),
        AppLocalizations.of(context),
        () => ref.read(databaseProvider).settingsDao.setDayStartHour(_hour),
      );
    }
    // Closed even on failure: the message shows under the sheet otherwise.
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final locale = context.localeName;
    String hour(int value) => formatTime(DateTime(2000, 1, 1, value), locale);
    final ends = textTheme.bodySmall!.copyWith(color: colors.textSecondary);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.menuDayStart, style: textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(
              l10n.dayStartSheetBody,
              style: textTheme.bodyLarge!.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: 18),
            Text(
              hour(_hour),
              textAlign: TextAlign.center,
              style: textTheme.displaySmall!.copyWith(fontSize: 36),
            ),
            Slider(
              value: _hour.toDouble(),
              max: maxAppDayStartHour.toDouble(),
              divisions: maxAppDayStartHour,
              inactiveColor: colors.divider,
              label: hour(_hour),
              semanticFormatterCallback: (value) => hour(value.round()),
              onChanged: (value) => setState(() => _hour = value.round()),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(hour(0), style: ends),
                  Text(hour(maxAppDayStartHour), style: ends),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }
}
