import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/domain/entry_mode.dart';
import 'package:protein_calculator/core/formatting.dart';
import 'package:protein_calculator/core/theme.dart';
import 'package:protein_calculator/core/widgets/grams_input_formatter.dart';
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
    final title = switch (args.kind) {
      EntryFormKind.newEntry => l10n.newEntryTitle,
      EntryFormKind.editEntry => l10n.editEntryTitle,
      EntryFormKind.newProduct => l10n.newProductTitle,
      EntryFormKind.editProduct => l10n.editProductTitle,
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
      body: form == null
          ? const SizedBox.shrink()
          : _FormView(key: ValueKey(form.revision), args: args, form: form),
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
    _nameFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final controller in [_name, _protein, _consumed, _per, _reference]) {
      controller.dispose();
    }
    _nameFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    final saved = await _notifier.submit();
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
    final locale = Localizations.localeOf(context).toString();

    String? error(EntryFormField field) => switch (form.errors[field]) {
      null => null,
      EntryFormError.required => l10n.errorRequired,
      EntryFormError.notPositive => l10n.errorNotPositive,
      EntryFormError.aboveReference => l10n.errorAboveReference,
      EntryFormError.nameRequired => l10n.errorNameRequired,
      EntryFormError.nameTaken => l10n.errorNameTaken,
    };

    final suggestions = args.isProduct || !_nameFocus.hasFocus
        ? const <Product>[]
        : ref.watch(productSuggestionsProvider(form.name));

    return SafeArea(
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
                  textInputAction: TextInputAction.next,
                  onChanged: _notifier.setName,
                  decoration: InputDecoration(
                    hintText: l10n.formNameHint,
                    errorText: error(EntryFormField.name),
                  ),
                ),
                if (suggestions.isNotEmpty)
                  _Suggestions(
                    products: suggestions,
                    locale: locale,
                    onSelected: (product) {
                      FocusScope.of(context).unfocus();
                      _notifier.applyProduct(product);
                    },
                  ),
                const SizedBox(height: 14),
                _ModeSelector(mode: form.mode, onChanged: _notifier.setMode),
                if (form.mode == EntryMode.direct) ...[
                  _Label(l10n.formProtein),
                  _GramsField(
                    controller: _protein,
                    onChanged: _notifier.setProtein,
                    errorText: error(EntryFormField.protein),
                  ),
                ] else ...[
                  _Label(args.isProduct ? l10n.formPortion : l10n.formConsumed),
                  _GramsField(
                    controller: _consumed,
                    onChanged: _notifier.setConsumed,
                    errorText: error(EntryFormField.consumed),
                  ),
                  _Label(l10n.formProductProtein),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _GramsField(
                          controller: _per,
                          onChanged: _notifier.setProteinPerReference,
                          errorText: error(EntryFormField.proteinPerReference),
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
                          onChanged: _notifier.setReference,
                          errorText: error(EntryFormField.reference),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _Result(grams: form.proteinGrams, locale: locale),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (args.kind == EntryFormKind.newEntry)
                  _SaveAsProduct(
                    value: form.saveAsProduct,
                    onChanged: _notifier.setSaveAsProduct,
                  ),
                FilledButton(
                  onPressed: _saving ? null : _submit,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: Text(
                    args.kind == EntryFormKind.newEntry
                        ? l10n.addEntry
                        : l10n.save,
                  ),
                ),
              ],
            ),
          ),
        ],
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
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    onChanged: onChanged,
    keyboardType: TextInputType.number,
    inputFormatters: [GramsInputFormatter()],
    textInputAction: TextInputAction.next,
    decoration: InputDecoration(
      suffixText: AppLocalizations.of(context).gramsUnit,
      errorText: errorText,
      errorMaxLines: 2,
    ),
  );
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.mode, required this.onChanged});

  final EntryMode mode;
  final ValueChanged<EntryMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final style = Theme.of(context).textTheme.bodyMedium!;

    Widget option(EntryMode value, String label) {
      final selected = value == mode;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          child: Material(
            color: selected ? AppColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            child: InkWell(
              borderRadius: BorderRadius.circular(9),
              onTap: () => onChanged(value),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: style.copyWith(
                    color: selected ? AppColors.onAccent : colors.textSecondary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
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
      child: Row(
        children: [
          option(EntryMode.direct, l10n.modeDirect),
          option(EntryMode.perQuantity, l10n.modePerQuantity),
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
  });

  final List<Product> products;
  final String locale;
  final ValueChanged<Product> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    String grams(double? value) => formatGrams(value ?? 0, locale);

    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
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
                      product.mode == EntryMode.direct
                          ? l10n.grams(grams(product.proteinGrams))
                          : l10n.productPerReference(
                              grams(product.proteinPerReference),
                              grams(product.referenceGrams),
                            ),
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
          value == null ? '–' : l10n.grams(formatGrams(value, locale)),
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
  const _SaveAsProduct({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onChanged(!value),
        child: Row(
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
            Text(
              AppLocalizations.of(context).saveAsProduct,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
