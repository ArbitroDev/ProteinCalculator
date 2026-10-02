import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/database/products_dao.dart';
import 'package:protein_calculator/core/domain/entry_mode.dart';
import 'package:protein_calculator/core/domain/product_sort.dart';
import 'package:protein_calculator/core/formatting.dart';
import 'package:protein_calculator/core/providers.dart';
import 'package:protein_calculator/core/router.dart';
import 'package:protein_calculator/core/theme.dart';
import 'package:protein_calculator/core/widgets/sliding_selector.dart';
import 'package:protein_calculator/core/widgets/undo_snack_bar.dart';
import 'package:protein_calculator/l10n/app_localizations.dart';

/// Products tab. Tap a product to edit it, tap its "+" button to add it to
/// the day, swipe it to delete it.
class ProductsPage extends ConsumerStatefulWidget {
  const ProductsPage({super.key});

  @override
  ConsumerState<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends ConsumerState<ProductsPage> {
  /// Products swiped away, hidden until the database confirms the deletion.
  final _hidden = <int>{};

  Future<void> _delete(Product product) async {
    setState(() => _hidden.add(product.id));
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final dao = ref.read(databaseProvider).productsDao;

    final deleted = await dao.deleteProduct(product.id);
    if (deleted == null) return;
    showUndoSnackBar(
      messenger,
      l10n: l10n,
      label: l10n.productDeleted,
      onUndo: () async {
        try {
          await dao.restoreProduct(deleted);
        } on DuplicateProductNameException {
          // A product with the same name was created meanwhile.
        }
        if (mounted) setState(() => _hidden.remove(product.id));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sort =
        ref.watch(productSortProvider).value ?? ProductSort.alphabetical;
    final products = ref.watch(sortedProductsProvider).value;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabProducts)),
      floatingActionButton: FilledButton.icon(
        onPressed: () => context.push(AppRoutes.newProduct),
        style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
        icon: const Icon(LucideIcons.plus, size: 20),
        label: Text(l10n.newProductTitle),
      ),
      body: products == null
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
                  child: _SortChips(
                    sort: sort,
                    onChanged: (value) => ref
                        .read(databaseProvider)
                        .settingsDao
                        .setProductSort(value),
                  ),
                ),
                Expanded(
                  child: _buildList([
                    for (final product in products)
                      if (!_hidden.contains(product.id)) product,
                  ], sort),
                ),
              ],
            ),
    );
  }

  Widget _buildList(List<Product> products, ProductSort sort) {
    if (products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            AppLocalizations.of(context).productsEmpty,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge!
                .copyWith(color: AppColors.of(context).textSecondary),
          ),
        ),
      );
    }
    return ListView.builder(
      // Room for the floating button over the last product.
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 88),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return _ProductTile(
          product: product,
          showUses: sort == ProductSort.mostUsed,
          onDelete: () => _delete(product),
        );
      },
    );
  }
}

class _SortChips extends StatelessWidget {
  const _SortChips({required this.sort, required this.onChanged});

  final ProductSort sort;
  final ValueChanged<ProductSort> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final style = Theme.of(context).textTheme.bodyMedium!;
    final labels = {
      ProductSort.alphabetical: l10n.sortAlphabetical,
      ProductSort.mostUsed: l10n.sortMostUsed,
      ProductSort.recentlyUsed: l10n.sortRecentlyUsed,
    };

    final options = labels.keys.toList();
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: ShapeDecoration(
        color: colors.surface,
        shape: StadiumBorder(side: BorderSide(color: colors.divider)),
      ),
      // Same look as the tab bar.
      child: SlidingSelector(
        selectedIndex: options.indexOf(sort),
        gap: 4,
        shape: const StadiumBorder(),
        children: [
          for (final value in options)
            Semantics(
              button: true,
              selected: value == sort,
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: () => onChanged(value),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Text(
                      labels[value]!,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: style.copyWith(
                        color: value == sort
                            ? AppColors.onAccent
                            : colors.textSecondary,
                        fontWeight: value == sort
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.showUses,
    required this.onDelete,
  });

  final Product product;
  final bool showUses;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toString();
    String grams(double? value) => formatGrams(value ?? 0, locale);

    final details = [
      if (product.mode == EntryMode.direct)
        l10n.grams(grams(product.proteinGrams))
      else ...[
        l10n.productPerReference(
          formatProteinContent(product.proteinPerReference ?? 0, locale),
          grams(product.referenceGrams),
        ),
        if (product.consumedGrams != null)
          l10n.productPortion(grams(product.consumedGrams)),
      ],
      if (showUses) l10n.productUseCount(product.useCount),
    ].join(' · ');

    return Semantics(
      customSemanticsActions: {
        CustomSemanticsAction(label: l10n.delete): onDelete,
      },
      child: Dismissible(
        key: ValueKey(product.id),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => onDelete(),
        background: Container(
          color: AppColors.danger,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 22),
          child: const Icon(LucideIcons.trash2, color: Colors.white),
        ),
        child: Material(
          color: colors.background,
          child: InkWell(
            onTap: () => context.push(AppRoutes.editProduct(product.id)),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: colors.divider)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: textTheme.bodyLarge!.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(details, style: textTheme.bodySmall),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Same look as the add button of the tab bar.
                  SizedBox.square(
                    dimension: 32,
                    child: IconButton.filled(
                      onPressed: () =>
                          context.push(AppRoutes.newEntryFrom(product.id)),
                      tooltip: l10n.addToToday,
                      padding: EdgeInsets.zero,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.onAccent,
                      ),
                      icon: const Icon(LucideIcons.plus, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
