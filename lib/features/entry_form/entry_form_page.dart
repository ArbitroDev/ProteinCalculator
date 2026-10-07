import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:protein_calculator/core/daily_routines.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/domain/daily_routine.dart';
import 'package:protein_calculator/core/domain/entry_mode.dart';
import 'package:protein_calculator/core/domain/product_name.dart';
import 'package:protein_calculator/core/formatting.dart';
import 'package:protein_calculator/core/theme.dart';
import 'package:protein_calculator/core/widgets/content_width.dart';
import 'package:protein_calculator/core/widgets/grams_input_formatter.dart';
import 'package:protein_calculator/core/widgets/locale_name.dart';
import 'package:protein_calculator/core/widgets/notifications_off.dart';
import 'package:protein_calculator/core/widgets/product_description.dart';
import 'package:protein_calculator/core/widgets/sliding_selector.dart';
import 'package:protein_calculator/core/widgets/user_action.dart';
import 'package:protein_calculator/features/entry_form/entry_form_notifier.dart';
import 'package:protein_calculator/features/entry_form/entry_form_state.dart';
import 'package:protein_calculator/l10n/app_localizations.dart';

/// Form adding or editing an entry, or creating or editing a product.
class EntryFormPage extends ConsumerWidget {
  const EntryFormPage({super.key, required this.args});

  final EntryFormArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final form = ref.watch(entryFormProvider(args)).value;
    final title = switch (args) {
      NewEntryArgs() => l10n.newEntryTitle,
      EditEntryArgs() => l10n.editEntryTitle,
      NewProductArgs() => l10n.newProductTitle,
      EditProductArgs() => l10n.editProductTitle,
    };

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.x),
          tooltip: l10n.close,
          onPressed: () => context.pop(),
        ),
        title: Text(title),
      ),
      body: ContentWidth(
        child: form == null
            ? const SizedBox.shrink()
            : _FormView(key: ValueKey(form.revision), args: args, form: form),
      ),
    );
  }
}

class _FormView extends ConsumerStatefulWidget {
  const _FormView({super.key, required this.args, required this.form});

  final EntryFormArgs args;

  /// Values the text fields start with.
  final EntryFormState form;

  @override
  ConsumerState<_FormView> createState() => _FormViewState();
}

class _FormViewState extends ConsumerState<_FormView> {
  late final TextEditingController _name;
  late final TextEditingController _protein;
  late final TextEditingController _consumed;
  late final TextEditingController _per;
  late final TextEditingController _reference;
  final _nameFocus = FocusNode();
  bool _saving = false;

  /// Suggestions show while the name field has the focus, until a product
  /// is picked or they are closed.
  late bool _hideSuggestions = widget.form.name.isNotEmpty;

  /// Whether the name field counts as focused for the suggestions. When it
  /// loses the focus during a tap, the suggestions only go away once the
  /// finger is lifted, so nothing moves under the tap.
  bool _nameActive = false;
  int _pointersDown = 0;
  bool _deactivatePending = false;

  void _onNameFocus() {
    if (_nameFocus.hasFocus) {
      _deactivatePending = false;
      if (!_nameActive) setState(() => _nameActive = true);
    } else if (_pointersDown > 0) {
      _deactivatePending = true;
    } else {
      setState(() => _nameActive = false);
    }
  }

  void _onPointerEnd(PointerEvent _) {
    _pointersDown = max(0, _pointersDown - 1);
    if (_pointersDown == 0 && _deactivatePending) {
      _deactivatePending = false;
      setState(() => _nameActive = false);
    }
  }

  void _dismissSuggestions() {
    if (!_hideSuggestions) setState(() => _hideSuggestions = true);
  }

  /// [change], hiding the suggestions first.
  ValueChanged<T> _dismissing<T>(ValueChanged<T> change) => (value) {
    _dismissSuggestions();
    change(value);
  };

  EntryFormNotifier get _notifier =>
      ref.read(entryFormProvider(widget.args).notifier);

  @override
  void initState() {
    super.initState();
    final form = widget.form;
    _name = TextEditingController(text: form.name);
    _protein = TextEditingController(text: form.protein);
    _consumed = TextEditingController(text: form.consumed);
    _per = TextEditingController(text: form.proteinPerReference);
    _reference = TextEditingController(text: form.reference);
    _nameFocus.addListener(_onNameFocus);
  }

  /// Whether the decimal separator of the user's language was applied.
  bool _localized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Once: running again would replace what the user is typing.
    if (_localized) return;
    _localized = true;
    final separator = NumberFormat.decimalPattern(context.localeName)
        .symbols
        .DECIMAL_SEP;
    // Protein amounts are the only values typed with a decimal.
    for (final controller in [_protein, _per]) {
      controller.text = controller.text.replaceAll('.', separator);
    }
  }

  @override
  void dispose() {
    for (final controller in [_name, _protein, _consumed, _per, _reference]) {
      controller.dispose();
    }
    _nameFocus.dispose();
    super.dispose();
  }

  /// Chooses the routine, asking to allow notifications first. A reminder
  /// is only a notification: it needs them. An automatic addition works
  /// without them, which the form then says.
  Future<void> _setRoutine(DailyRoutine routine) async {
    final status = ref.read(notificationStatusProvider.notifier);
    final shows =
        ref.read(notificationStatusProvider).value?.shows(routine) ?? true;
    final reminder = routine == DailyRoutine.reminder;
    if (!reminder || shows) _notifier.setRoutine(routine);
    if (routine == DailyRoutine.none || shows) return;

    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final allowed = await status.request(routine);
    if (!reminder) return;
    if (allowed) {
      _notifier.setRoutine(routine);
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.reminderNeedsNotifications),
          action: SnackBarAction(
            label: l10n.openSettings,
            onPressed: status.openSettings,
          ),
        ),
      );
    }
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    final saved =
        await runUserAction(messenger, l10n, _notifier.submit) ?? false;
    if (!mounted) return;
    if (saved) {
      context.pop();
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final form = ref.watch(entryFormProvider(widget.args)).value!;
    final args = widget.args;
    final locale = context.localeName;

    String? error(EntryFormField field) => switch (form.errors[field]) {
      null => null,
      EntryFormError.required => l10n.errorRequired,
      EntryFormError.notPositive => l10n.errorNotPositive,
      EntryFormError.aboveReference => l10n.errorAboveReference,
      EntryFormError.nameRequired => l10n.errorNameRequired,
      EntryFormError.nameTaken => l10n.errorNameTaken,
    };

    final notifications = ref.watch(notificationStatusProvider).value;
    bool notified(DailyRoutine routine) =>
        notifications?.shows(routine) ?? true;

    final suggestions = args.isProduct || _hideSuggestions || !_nameActive
        ? const <Product>[]
        : ref.watch(productSuggestionsProvider(form.name));

    return Listener(
      onPointerDown: (_) => _pointersDown++,
      onPointerUp: _onPointerEnd,
      onPointerCancel: _onPointerEnd,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
                children: [
                  _Label(
                    args.isProduct || form.saveAsProduct
                        ? l10n.formName
                        : l10n.formNameOptional,
                  ),
                  TextField(
                    controller: _name,
                    focusNode: _nameFocus,
                    textCapitalization: TextCapitalization.sentences,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(maxNameLength),
                    ],
                    textInputAction: TextInputAction.next,
                    onChanged: (value) {
                      if (_hideSuggestions) {
                        setState(() => _hideSuggestions = false);
                      }
                      _notifier.setName(value);
                    },
                    decoration: InputDecoration(
                      hintText: l10n.formNameHint,
                      errorText: error(EntryFormField.name),
                    ),
                  ),
                  // Always one slot, even when empty: the fields after it keep
                  // their place in the list, so the field being tapped is not
                  // rebuilt (it would lose the focus, which would go back to
                  // the name).
                  if (suggestions.isEmpty)
                    const SizedBox.shrink()
                  else
                    _Suggestions(
                      products: suggestions,
                      locale: locale,
                      onSelected: (product) {
                        FocusScope.of(context).unfocus();
                        _dismissSuggestions();
                        _notifier.applyProduct(product);
                      },
                      onClose: _dismissSuggestions,
                    ),
                  const SizedBox(height: 14),
                  _OptionSelector(
                    values: EntryMode.values,
                    selected: form.mode,
                    label: (value) => switch (value) {
                      EntryMode.direct => l10n.modeDirect,
                      EntryMode.perQuantity => l10n.modePerQuantity,
                    },
                    onChanged: _dismissing(_notifier.setMode),
                  ),
                  if (form.mode == EntryMode.direct) ...[
                    _Label(l10n.formProtein),
                    _GramsField(
                      controller: _protein,
                      decimal: true,
                      onChanged: _dismissing(_notifier.setProtein),
                      errorText: error(EntryFormField.protein),
                    ),
                  ] else ...[
                    _Label(
                      args.isProduct ? l10n.formPortion : l10n.formConsumed,
                    ),
                    _GramsField(
                      controller: _consumed,
                      onChanged: _dismissing(_notifier.setConsumed),
                      errorText: error(EntryFormField.consumed),
                    ),
                    _Label(l10n.formProductProtein),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _GramsField(
                            controller: _per,
                            decimal: true,
                            onChanged: _dismissing(
                              _notifier.setProteinPerReference,
                            ),
                            errorText: error(
                              EntryFormField.proteinPerReference,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 14, 10, 0),
                          child: Text(
                            l10n.formPer,
                            style: Theme.of(context).textTheme.bodyLarge!
                                .copyWith(
                                  color: AppColors.of(context).textSecondary,
                                ),
                          ),
                        ),
                        Expanded(
                          child: _GramsField(
                            controller: _reference,
                            onChanged: _dismissing(_notifier.setReference),
                            errorText: error(EntryFormField.reference),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _Result(grams: form.amount?.proteinGrams, locale: locale),
                  ],
                  if (args is! EditEntryArgs) ...[
                    const SizedBox(height: 8),
                    _Label(l10n.routineTitle),
                    _OptionSelector(
                      values: DailyRoutine.values,
                      selected: form.routine,
                      label: (value) => switch (value) {
                        DailyRoutine.none => l10n.routineNone,
                        DailyRoutine.reminder => l10n.routineReminder,
                        DailyRoutine.autoAdd => l10n.routineAutoAdd,
                      },
                      onChanged: _dismissing(_setRoutine),
                      // Still tapped: it asks for the notifications.
                      disabled: {
                        if (!notified(DailyRoutine.reminder))
                          DailyRoutine.reminder,
                      },
                    ),
                    if (form.routine != DailyRoutine.none) ...[
                      _RoutineTime(
                        routine: form.routine,
                        minutes: form.routineMinutes,
                        locale: locale,
                        onChanged: _notifier.setRoutineMinutes,
                      ),
                      if (!notified(form.routine))
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: NotificationsOff(
                            message: form.routine == DailyRoutine.reminder
                                ? l10n.notificationsOffReminder
                                : l10n.notificationsOffAutoAdd,
                          ),
                        ),
                    ],
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (args is NewEntryArgs)
                    _SaveAsProduct(
                      value: form.saveAsProduct,
                      label: form.updatesProduct
                          ? l10n.updateProduct
                          : l10n.saveAsProduct,
                      // Locked on while a routine is chosen: it belongs to
                      // the product.
                      onChanged:
                          form.canSaveAsProduct &&
                              form.routine == DailyRoutine.none
                          ? _notifier.setSaveAsProduct
                          : null,
                    ),
                  FilledButton(
                    onPressed: _saving ? null : _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: Text(
                      args is NewEntryArgs ? l10n.addEntry : l10n.save,
                    ),
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

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 6),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium!
          .copyWith(color: AppColors.of(context).textSecondary),
    ),
  );
}

class _GramsField extends StatelessWidget {
  const _GramsField({
    required this.controller,
    required this.onChanged,
    required this.errorText,
    this.decimal = false,
  });

  final TextEditingController controller;

  /// Allows one decimal: protein amounts take one, quantities of food none.
  final bool decimal;
  final ValueChanged<String> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    onChanged: onChanged,
    keyboardType: TextInputType.numberWithOptions(decimal: decimal),
    inputFormatters: [GramsInputFormatter(maxDecimals: decimal ? 1 : 0)],
    textInputAction: TextInputAction.next,
    decoration: InputDecoration(
      suffixText: AppLocalizations.of(context).gramsUnit,
      errorText: errorText,
      errorMaxLines: 2,
    ),
  );
}

/// Options of equal width, the selected one on a sliding pill.
class _OptionSelector<T> extends StatelessWidget {
  const _OptionSelector({
    required this.values,
    required this.selected,
    required this.label,
    required this.onChanged,
    this.disabled = const {},
  });

  final List<T> values;
  final T selected;
  final String Function(T value) label;
  final ValueChanged<T> onChanged;

  /// Options shown as unavailable, which still call [onChanged] when tapped.
  final Set<T> disabled;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final style = Theme.of(context).textTheme.bodyMedium!;

    Widget option(T value) {
      final isSelected = value == selected;
      final isDisabled = disabled.contains(value);
      final color = isSelected
          ? AppColors.onAccent
          : colors.textSecondary.withValues(alpha: isDisabled ? 0.5 : 1);
      return Semantics(
        button: true,
        selected: isSelected,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(9),
            onTap: () => onChanged(value),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isDisabled) ...[
                    Icon(LucideIcons.bellOff, size: 14, color: color),
                    const SizedBox(width: 5),
                  ],
                  Flexible(
                    child: Text(
                      label(value),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: style.copyWith(
                        color: color,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SlidingSelector(
        selectedIndex: values.indexOf(selected),
        gap: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        children: [for (final value in values) option(value)],
      ),
    );
  }
}

/// What the chosen routine does, and its time, tapped to change it.
class _RoutineTime extends StatelessWidget {
  const _RoutineTime({
    required this.routine,
    required this.minutes,
    required this.locale,
    required this.onChanged,
  });

  final DailyRoutine routine;
  final int minutes;
  final String locale;
  final ValueChanged<int> onChanged;

  Future<void> _pick(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
    if (picked != null) onChanged(picked.hour * 60 + picked.minute);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              routine == DailyRoutine.reminder
                  ? l10n.routineReminderHint
                  : l10n.routineAutoAddHint,
              style: textTheme.bodySmall!.copyWith(color: colors.textSecondary),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: () => _pick(context),
            icon: const Icon(LucideIcons.clock, size: 18),
            label: Text(
              l10n.routineAt(
                formatTime(routineTimeOn(DateTime(2000), minutes), locale),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Suggestions extends StatelessWidget {
  const _Suggestions({
    required this.products,
    required this.locale,
    required this.onSelected,
    required this.onClose,
  });

  final List<Product> products;
  final String locale;
  final ValueChanged<Product> onSelected;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.suggestionsTitle,
                    style: textTheme.bodySmall,
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  tooltip: l10n.close,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    LucideIcons.x,
                    size: 18,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          for (final product in products)
            InkWell(
              onTap: () => onSelected(product),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(product.name, style: textTheme.bodyLarge),
                    ),
                    Text(
                      describeProduct(l10n, product),
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

class _Result extends StatelessWidget {
  const _Result({required this.grams, required this.locale});

  final double? grams;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final value = grams;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          value == null ? '–' : l10n.grams(formatProtein(value, locale)),
          style: textTheme.displaySmall!.copyWith(color: colors.accentText),
        ),
        const SizedBox(width: 8),
        Text(
          l10n.formResult,
          style: textTheme.bodyLarge!.copyWith(color: colors.textSecondary),
        ),
      ],
    );
  }
}

class _SaveAsProduct extends StatelessWidget {
  const _SaveAsProduct({
    required this.value,
    required this.label,
    required this.onChanged,
  });

  final bool value;
  final String label;

  /// Null while the option is not available.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final onChanged = this.onChanged;
    final enabled = onChanged != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: enabled ? () => onChanged(!value) : null,
        child: Row(
          children: [
            Checkbox(
              value: value,
              onChanged: enabled
                  ? (checked) => onChanged(checked ?? false)
                  : null,
            ),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyLarge!
                    .copyWith(color: enabled ? null : colors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
