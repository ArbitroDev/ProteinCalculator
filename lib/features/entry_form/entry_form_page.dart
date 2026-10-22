import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:protein_calculator/core/daily_routines.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/database/products_dao.dart';
import 'package:protein_calculator/core/domain/creatine.dart';
import 'package:protein_calculator/core/domain/daily_routine.dart';
import 'package:protein_calculator/core/domain/entry_mode.dart';
import 'package:protein_calculator/core/domain/product_name.dart';
import 'package:protein_calculator/core/domain/quantity_unit.dart';
import 'package:protein_calculator/core/food_facts/open_food_facts.dart';
import 'package:protein_calculator/core/formatting.dart';
import 'package:protein_calculator/core/providers.dart';
import 'package:protein_calculator/core/router.dart';
import 'package:protein_calculator/core/theme.dart';
import 'package:protein_calculator/core/widgets/content_width.dart';
import 'package:protein_calculator/core/widgets/creatine_mark.dart';
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
class EntryFormPage extends ConsumerStatefulWidget {
  const EntryFormPage({super.key, required this.args});

  final EntryFormArgs args;

  @override
  ConsumerState<EntryFormPage> createState() => _EntryFormPageState();
}

/// Holds what lasts while the form view is built again with new values,
/// such as a scan and what follows it.
class _EntryFormPageState extends ConsumerState<EntryFormPage> {
  /// Whether the product of a barcode scanned is being looked up.
  bool _lookingUp = false;

  EntryFormNotifier get _notifier =>
      ref.read(entryFormProvider(widget.args).notifier);

  /// Scans a barcode and fills the form from its product, then tells what
  /// is worth knowing: a value Open Food Facts lacks, a product of the user
  /// with the same name, newer values.
  Future<void> _scan() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final router = GoRouter.of(context);
    final products = ref.read(databaseProvider).productsDao;
    final language = Localizations.localeOf(context).languageCode;
    if (!await _readScanNotice() || !mounted) return;
    final barcode = await context.push<String>(AppRoutes.scan);
    if (barcode == null || !mounted) return;

    setState(() => _lookingUp = true);
    final outcome = await runUserAction(
      messenger,
      l10n,
      () => _notifier.scanned(barcode, language: language),
    );
    if (!mounted) return;
    setState(() => _lookingUp = false);

    // A message with an action goes away after a while like the others,
    // rather than staying on the next pages once the form is closed; its
    // action, tapped maybe after, works without the form.
    void tell(String message, {SnackBarAction? action}) =>
        messenger.showSnackBar(
          SnackBar(content: Text(message), action: action, persist: false),
        );

    switch (outcome) {
      case null || ScanKept():
        break;
      case ScanFoundProduct(:final product, :final update):
        final facts = await update;
        if (facts == null || !mounted) return;
        tell(
          l10n.scanProductChanged(
            product.name,
            l10n.productPerReference(
              formatProtein(facts.proteinPer100!, l10n.localeName),
              formatQuantity(l10n, 100, facts.unit),
            ),
          ),
          action: SnackBarAction(
            label: l10n.scanTakeChange,
            onPressed: () => runUserAction(messenger, l10n, () async {
              if (mounted) return _notifier.takeFoodFacts(product, facts);
              await products.setProteinPer100(
                product.id,
                facts.proteinPer100!,
                unit: facts.unit,
              );
            }),
          ),
        );
      case ScanFilled(:final scan, :final sameName, :final update):
        if (sameName != null) {
          tell(
            l10n.scanNameTaken(sameName.name),
            action: SnackBarAction(
              label: l10n.scanGiveBarcode,
              onPressed: () =>
                  _giveBarcode(sameName, barcode, messenger, l10n, products),
            ),
          );
        } else if (scan.proteinPer100 == null) {
          tell(l10n.scanNoProtein);
        } else if (scan.proteinPer100 == 0) {
          tell(l10n.scanZeroProtein);
        }
        final fresh = await update;
        if (fresh == null || !mounted) return;
        _notifier.refreshFromFoodFacts(fresh);
        tell(l10n.scanUpdated);
      case ScanBarcodeTaken(:final product):
        tell(
          l10n.scanBarcodeTaken(product.name),
          action: SnackBarAction(
            label: l10n.scanOpenProduct,
            onPressed: () {
              final edit = AppRoutes.editProduct(product.id);
              if (mounted) {
                context.pushReplacement(edit);
              } else {
                unawaited(router.push(edit));
              }
            },
          ),
        );
      case ScanNotFound(:final problem, :final storeCode):
        tell(switch (problem) {
          null when storeCode => l10n.scanStoreCode,
          null => l10n.scanNotFound,
          FoodFactsProblem.offline => l10n.scanOffline,
          FoodFactsProblem.busy => l10n.scanBusy,
          FoodFactsProblem.timeout ||
          FoodFactsProblem.failed => l10n.scanUnavailable,
        });
    }
  }

  /// Before the first scan, tells what is sent to Open Food Facts. Returns
  /// whether the user goes on, which is not asked again.
  Future<bool> _readScanNotice() async {
    final settings = ref.read(databaseProvider).settingsDao;
    if (await settings.getScanNoticeSeen()) return true;
    if (!mounted) return false;
    final l10n = AppLocalizations.of(context);
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.scanBarcode),
        content: Text(l10n.scanNotice),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.scanNoticeAccept),
          ),
        ],
      ),
    );
    if (accepted != true) return false;
    await settings.setScanNoticeSeen();
    return true;
  }

  /// Gives [barcode] to [product], the user's product of the same name, in
  /// place of the values of Open Food Facts. A new product is then not
  /// needed: its form closes. Once the form is closed, the product still
  /// takes the barcode, with [products].
  Future<void> _giveBarcode(
    Product product,
    String barcode,
    ScaffoldMessengerState messenger,
    AppLocalizations l10n,
    ProductsDao products,
  ) async {
    final given = await runUserAction(messenger, l10n, () async {
      if (mounted) {
        await _notifier.giveBarcode(product, barcode);
      } else {
        await products.setBarcode(product.id, barcode);
      }
      return true;
    });
    if (given == null) return;
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.scanBarcodeGiven(product.name))),
    );
    if (mounted && widget.args is NewProductArgs) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final args = widget.args;
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
            : _FormView(
                key: ValueKey(form.revision),
                args: args,
                form: form,
                onScan: _scan,
                lookingUp: _lookingUp,
              ),
      ),
    );
  }
}

class _FormView extends ConsumerStatefulWidget {
  const _FormView({
    super.key,
    required this.args,
    required this.form,
    required this.onScan,
    required this.lookingUp,
  });

  final EntryFormArgs args;

  /// Values the text fields start with.
  final EntryFormState form;

  /// Scans a barcode and fills the form from its product.
  final Future<void> Function() onScan;

  /// Whether the product of a barcode scanned is being looked up.
  final bool lookingUp;

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

  /// Whether the creatine counter shows: while creatine is tracked, or for
  /// values holding doses. Once shown, it stays, even back to zero.
  bool _creatineShown = false;

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
  /// without them, which the form then says. Then asks for exact times, so
  /// the notifications are not delayed.
  Future<void> _setRoutine(DailyRoutine routine) async {
    final status = ref.read(notificationStatusProvider.notifier);
    final shows =
        ref.read(notificationStatusProvider).value?.shows(routine) ?? true;
    final reminder = routine == DailyRoutine.reminder;
    if (!reminder || shows) _notifier.setRoutine(routine);
    if (routine == DailyRoutine.none) return;

    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    if (!shows && !await status.request(routine)) {
      if (!reminder) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.reminderNeedsNotifications),
          action: SnackBarAction(
            label: l10n.openSettings,
            onPressed: status.openSettings,
          ),
        ),
      );
      return;
    }
    if (reminder && !shows) _notifier.setRoutine(routine);
    if (mounted) await askExactAlarms(context, ref);
  }

  /// Whether the form offers to scan a barcode: not for an entry being
  /// edited, nor on the web, which only serves to try the app.
  bool get _canScan => !kIsWeb && widget.args is! EditEntryArgs;

  /// Hides the suggestions, then scans a barcode, see [_FormView.onScan].
  Future<void> _scan() async {
    _dismissSuggestions();
    await widget.onScan();
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
      EntryFormError.future => l10n.errorFutureTime,
      EntryFormError.barcodeTaken => l10n.errorBarcodeTaken,
    };

    /// Background of the fields Open Food Facts filled in, like the scan
    /// button; the theme's for the others.
    Color? fill(EntryFormField field) => form.fromFoodFacts.contains(field)
        ? AppColors.of(context).scanSurface
        : null;

    final notifications = ref.watch(notificationStatusProvider).value;
    bool notified(DailyRoutine routine) =>
        notifications?.shows(routine) ?? true;

    final creatine = ref.watch(creatineSettingsProvider).value;
    _creatineShown =
        _creatineShown ||
        (creatine?.enabled ?? false) ||
        form.creatineDoses > 0;

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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
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
                            fillColor: fill(EntryFormField.name),
                          ),
                        ),
                      ),
                      if (_canScan) ...[
                        const SizedBox(width: 10),
                        _ScanButton(
                          onPressed: widget.lookingUp ? null : _scan,
                          busy: widget.lookingUp,
                        ),
                      ],
                    ],
                  ),
                  // Always one slot, like the suggestions below.
                  if (form.barcode case final barcode?
                      when args.isProduct || form.saveAsProduct)
                    _BarcodeLine(
                      barcode: barcode,
                      errorText: error(EntryFormField.barcode),
                      onRemove: () => _notifier.setBarcode(null),
                    )
                  else
                    const SizedBox.shrink(),
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
                      fillColor: fill(EntryFormField.protein),
                    ),
                  ] else ...[
                    _Label(
                      args.isProduct ? l10n.formPortion : l10n.formConsumed,
                    ),
                    _GramsField(
                      controller: _consumed,
                      unit: form.unit,
                      onUnitChanged: _dismissing(_notifier.setUnit),
                      onChanged: _dismissing(_notifier.setConsumed),
                      errorText: error(EntryFormField.consumed),
                      fillColor: fill(EntryFormField.consumed),
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
                            fillColor: fill(EntryFormField.proteinPerReference),
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
                            unit: form.unit,
                            onChanged: _dismissing(_notifier.setReference),
                            errorText: error(EntryFormField.reference),
                            fillColor: fill(EntryFormField.reference),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _Result(grams: form.amount?.proteinGrams, locale: locale),
                  ],
                  if (_creatineShown) ...[
                    _Label(l10n.creatine, icon: creatineIcon),
                    _CreatineCounter(
                      doses: form.creatineDoses,
                      doseGrams:
                          form.creatineDoseGrams ??
                          creatine?.doseGrams ??
                          defaultCreatineDoseGrams,
                      locale: locale,
                      onChanged: _dismissing(_notifier.setCreatineDoses),
                    ),
                  ],
                  if (!args.isProduct) ...[
                    _Label(l10n.formWhen),
                    _EntryTime(
                      time: form.time,
                      now: ref.read(clockProvider)(),
                      locale: locale,
                      // An entry being edited keeps a time of its own.
                      canReset: args is NewEntryArgs,
                      errorText: error(EntryFormField.time),
                      onChanged: _dismissing(_notifier.setTime),
                    ),
                  ],
                  if (args.isProduct || form.saveAsProduct) ...[
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
                        )
                      else if (notifications?.exact == false)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: NotificationsOff(
                            message: l10n.routineMayBeLate,
                            late: true,
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
                  if (!args.isProduct)
                    _SaveAsProduct(
                      value: form.saveAsProduct,
                      label: l10n.saveAsProduct,
                      // A new product needs a name of its own.
                      hint: form.nameTaken ? l10n.errorNameTaken : null,
                      onChanged: form.nameTaken
                          ? null
                          : _notifier.setSaveAsProduct,
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

/// Opens the camera to scan the barcode of a product. Its green tells the
/// values it fills in.
class _ScanButton extends StatelessWidget {
  const _ScanButton({required this.onPressed, required this.busy});

  /// Null while [busy].
  final VoidCallback? onPressed;

  /// Whether the product of the barcode scanned is being looked up.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return IconButton(
      onPressed: onPressed,
      tooltip: AppLocalizations.of(context).scanBarcode,
      style: IconButton.styleFrom(
        backgroundColor: colors.scanSurface,
        foregroundColor: colors.scan,
        disabledBackgroundColor: colors.scanSurface,
        // As tall as the name field beside it.
        fixedSize: const Size.square(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: busy
          ? SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: colors.scan,
              ),
            )
          : const Icon(LucideIcons.scanBarcode),
    );
  }
}

/// Barcode the product takes, with a button taking it away.
class _BarcodeLine extends StatelessWidget {
  const _BarcodeLine({
    required this.barcode,
    required this.errorText,
    required this.onRemove,
  });

  final String barcode;
  final String? errorText;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.barcode, size: 18, color: colors.scan),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.formBarcode(barcode),
                  style: textTheme.bodyMedium!.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
              IconButton(
                onPressed: onRemove,
                tooltip: l10n.formRemoveBarcode,
                icon: Icon(
                  LucideIcons.x,
                  size: 18,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
          if (errorText case final error?)
            Text(
              error,
              style: Theme.of(context).inputDecorationTheme.errorStyle,
            ),
        ],
      ),
    );
  }
}

/// Creatine doses of the entry or of one portion of the product, with
/// buttons to take one off or add one, and the grams they amount to.
class _CreatineCounter extends StatelessWidget {
  const _CreatineCounter({
    required this.doses,
    required this.doseGrams,
    required this.locale,
    required this.onChanged,
  });

  final int doses;

  /// Grams of one dose.
  final double doseGrams;
  final String locale;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: doses > 0 ? () => onChanged(doses - 1) : null,
            tooltip: l10n.lessCreatine,
            icon: const Icon(LucideIcons.minus, size: 20),
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$doses',
              textAlign: TextAlign.center,
              style: textTheme.titleMedium,
            ),
          ),
          IconButton(
            onPressed: doses < maxCreatineDoses
                ? () => onChanged(doses + 1)
                : null,
            tooltip: l10n.moreCreatine,
            icon: const Icon(LucideIcons.plus, size: 20),
          ),
          const Spacer(),
          if (doses > 0) ...[
            CreatineMark(doses: 1, size: 16),
            const SizedBox(width: 6),
            Text(
              '${l10n.creatineDoses(doses)} · '
              '${l10n.grams(formatProtein(doses * doseGrams, locale))}',
              style: textTheme.bodyMedium!.copyWith(
                color: colors.creatineText,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {this.icon});

  final String text;

  /// Shown before the text, in the blue of creatine: only creatine has one.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final label = Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium!
          .copyWith(color: colors.textSecondary),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: icon == null
          ? label
          : Row(
              children: [
                Icon(icon, size: 16, color: colors.creatineText),
                const SizedBox(width: 6),
                label,
              ],
            ),
    );
  }
}

class _GramsField extends StatelessWidget {
  const _GramsField({
    required this.controller,
    required this.onChanged,
    required this.errorText,
    this.decimal = false,
    this.unit = QuantityUnit.grams,
    this.onUnitChanged,
    this.fillColor,
  });

  final TextEditingController controller;

  /// Allows one decimal: protein amounts take one, quantities of food none.
  final bool decimal;

  /// Unit shown after the value: protein amounts are always in grams.
  final QuantityUnit unit;

  /// Lets the user pick the [unit] in a list, shown in place of its symbol.
  final ValueChanged<QuantityUnit>? onUnitChanged;

  /// Background of the field, the theme's if null.
  final Color? fillColor;
  final ValueChanged<String> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final onUnitChanged = this.onUnitChanged;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      inputFormatters: [GramsInputFormatter(maxDecimals: decimal ? 1 : 0)],
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        suffixText: onUnitChanged == null
            ? quantityUnitSymbol(AppLocalizations.of(context), unit)
            : null,
        suffixIcon: onUnitChanged == null
            ? null
            : _UnitList(unit: unit, onChanged: onUnitChanged),
        errorText: errorText,
        errorMaxLines: 2,
        fillColor: fillColor,
      ),
    );
  }
}

/// List of the units of a quantity, at the end of its field.
class _UnitList extends StatelessWidget {
  const _UnitList({required this.unit, required this.onChanged});

  final QuantityUnit unit;
  final ValueChanged<QuantityUnit> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    return Semantics(
      label: l10n.formUnit,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sets the list apart from the value: only the unit opens it.
          Container(
            width: 1,
            height: 24,
            color: colors.textSecondary.withValues(alpha: 0.3),
          ),
          const SizedBox(width: 14),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 10),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<QuantityUnit>(
                value: unit,
                isDense: true,
                borderRadius: BorderRadius.circular(10),
                dropdownColor: colors.surfaceRaised,
                icon: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 6),
                  child: Icon(
                    LucideIcons.chevronDown,
                    size: 16,
                    color: colors.textSecondary,
                  ),
                ),
                style: Theme.of(context).textTheme.bodyLarge,
                items: [
                  for (final value in QuantityUnit.values)
                    DropdownMenuItem(
                      value: value,
                      child: Text(quantityUnitSymbol(l10n, value)),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) onChanged(value);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
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

/// Moment of an entry: now for a new one, until a day and a time are
/// picked, to add afterwards what was forgotten.
class _EntryTime extends StatelessWidget {
  const _EntryTime({
    required this.time,
    required this.now,
    required this.locale,
    required this.canReset,
    required this.errorText,
    required this.onChanged,
  });

  final DateTime? time;
  final DateTime now;
  final String locale;

  /// Whether a button sets the moment back to now.
  final bool canReset;
  final String? errorText;
  final ValueChanged<DateTime?> onChanged;

  Future<void> _pick(BuildContext context) async {
    final current = time ?? now;
    final initial = current.isAfter(now) ? now : current;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(min(2000, initial.year)),
      lastDate: now,
    );
    if (date == null || !context.mounted) return;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (picked == null) return;
    onChanged(
      DateTime(date.year, date.month, date.day, picked.hour, picked.minute),
    );
  }

  String _label(AppLocalizations l10n) {
    final time = this.time;
    if (time == null) return l10n.formNow;
    final today = DateUtils.dateOnly(now);
    final day = DateUtils.dateOnly(time);
    final dayText = day == today
        ? l10n.formToday
        : day == DateTime(today.year, today.month, today.day - 1)
        ? l10n.formYesterday
        : formatShortDate(time, locale);
    return l10n.formDayAt(dayText, formatTime(time, locale));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final error = errorText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () => _pick(context),
              icon: const Icon(LucideIcons.clock, size: 18),
              label: Text(_label(l10n)),
            ),
            if (canReset && time != null) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => onChanged(null),
                child: Text(l10n.formNow),
              ),
            ],
          ],
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 12),
            child: Text(
              error,
              style: Theme.of(context).textTheme.bodySmall!
                  .copyWith(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
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
    required this.hint,
    required this.onChanged,
  });

  final bool value;
  final String label;

  /// Why the option is not available, under its label.
  final String? hint;

  /// Null while the option is not available.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final onChanged = this.onChanged;
    final enabled = onChanged != null;
    final labelStyle = textTheme.bodyLarge!.copyWith(
      color: enabled ? null : colors.textSecondary,
    );
    // Height of the line of the label, so the box can be centered on it
    // whatever the text size chosen on the phone.
    final line = TextPainter(
      text: TextSpan(text: label, style: labelStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final lineHeight = line.height;
    line.dispose();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: enabled ? () => onChanged(!value) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The box itself sits on the left edge of the button below:
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
                        onChanged: enabled
                            ? (checked) => onChanged(checked ?? false)
                            : null,
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
                    Text(label, style: labelStyle),
                    if (hint case final hint?)
                      Text(
                        hint,
                        style: textTheme.bodySmall!.copyWith(fontSize: 11),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
