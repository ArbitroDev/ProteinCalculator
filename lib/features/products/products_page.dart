import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:protein_calculator/core/daily_routines.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/database/products_dao.dart';
import 'package:protein_calculator/core/domain/daily_routine.dart';
import 'package:protein_calculator/core/domain/product_name.dart';
import 'package:protein_calculator/core/domain/product_sort.dart';
import 'package:protein_calculator/core/formatting.dart';
import 'package:protein_calculator/core/providers.dart';
import 'package:protein_calculator/core/router.dart';
import 'package:protein_calculator/core/theme.dart';
import 'package:protein_calculator/core/widgets/content_width.dart';
import 'package:protein_calculator/core/widgets/creatine_mark.dart';
import 'package:protein_calculator/core/widgets/empty_state.dart';
import 'package:protein_calculator/core/widgets/locale_name.dart';
import 'package:protein_calculator/core/widgets/notifications_off.dart';
import 'package:protein_calculator/core/widgets/pill_tabs.dart';
import 'package:protein_calculator/core/widgets/product_description.dart';
import 'package:protein_calculator/core/widgets/swipe_to_delete.dart';
import 'package:protein_calculator/core/widgets/user_action.dart';
import 'package:protein_calculator/l10n/app_localizations.dart';

/// Products tab. Tap a product to edit it, long press it to create a new
/// product from its values, tap its "+" button to add it to the day, swipe
/// it to delete it. The favorite comes first, then the saved
/// products, those with a daily routine first, then the recent scans, which
/// tap to save as products. Both lists fold.
class ProductsPage extends ConsumerStatefulWidget {
  const ProductsPage({super.key});

  @override
  ConsumerState<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends ConsumerState<ProductsPage>
    with UndoableDeletion {
  Future<void> _delete(Product product) {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final dao = ref.read(databaseProvider).productsDao;
    return deleteWithUndo(
      id: product.id,
      delete: () => dao.deleteProduct(product.id),
      restore: (deleted) async {
        try {
          await dao.restoreProduct(deleted);
        } on DuplicateProductNameException {
          // A product with the same name was created meanwhile.
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.productRestoreNameTaken)),
          );
        }
      },
      label: l10n.productDeleted,
    );
  }

  Future<void> _deleteScan(ScannedProduct scan) {
    final dao = ref.read(databaseProvider).scansDao;
    return deleteWithUndo(
      id: scan.barcode,
      delete: () => dao.deleteScan(scan.barcode),
      restore: dao.restoreScan,
      label: AppLocalizations.of(context).scanDeleted,
    );
  }

  /// Runs a change of the products, telling the user if it fails.
  Future<void> _run(Future<void> Function() action) => runUserAction(
    ScaffoldMessenger.of(context),
    AppLocalizations.of(context),
    action,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sort =
        ref.watch(productSortProvider).value ?? ProductSort.alphabetical;
    final products = ref.watch(sortedProductsProvider).value;
    final scans = ref.watch(recentScansProvider).value ?? const [];
    final notifications = ref.watch(notificationStatusProvider).value;
    // Some routines cannot notify, or only late: a banner says so.
    final routines = [
      for (final product in products ?? const <Product>[])
        if (product.activeRoutineMinutes != null) product.routine,
    ];
    final unnotified =
        notifications != null &&
        routines.any((routine) => !notifications.shows(routine));
    final late =
        !unnotified && routines.isNotEmpty && notifications?.exact == false;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabProducts)),
      floatingActionButton: FilledButton.icon(
        onPressed: () => context.push(AppRoutes.newProduct),
        style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
        icon: const Icon(LucideIcons.plus, size: 20),
        label: Text(l10n.newProductTitle),
      ),
      body: ContentWidth(
        child: products == null
            ? const SizedBox.shrink()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
                    child: _SortChips(
                      sort: sort,
                      onChanged: (value) => _run(
                        () => ref
                            .read(databaseProvider)
                            .settingsDao
                            .setProductSort(value),
                      ),
                    ),
                  ),
                  if (unnotified || late)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
                      child: NotificationsOff(
                        message: unnotified
                            ? l10n.notificationsOffBanner
                            : l10n.routinesMayBeLateBanner,
                        late: late,
                      ),
                    ),
                  Expanded(
                    child: _buildList(
                      [
                        for (final product in products)
                          if (!isDeleted(product.id)) product,
                      ],
                      [
                        for (final scan in scans)
                          if (!isDeleted(scan.barcode)) scan,
                      ],
                      sort,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildList(
    List<Product> products,
    List<ScannedProduct> scans,
    ProductSort sort,
  ) {
    final l10n = AppLocalizations.of(context);
    if (products.isEmpty && scans.isEmpty) {
      return EmptyState(l10n.productsEmpty);
    }
    final settings = ref.read(databaseProvider).settingsDao;
    final savedCollapsed =
        ref.watch(savedProductsCollapsedProvider).value ?? false;
    final scansCollapsed =
        ref.watch(recentScansCollapsedProvider).value ?? false;
    // Always on top, even with its list folded.
    final favorite = products.where((p) => p.isFavorite).firstOrNull;
    final others = [
      for (final product in products)
        if (!product.isFavorite) product,
    ];

    Widget productTile(Product product) => _ProductTile(
      product: product,
      showUses: sort == ProductSort.mostUsed,
      onDelete: () => _delete(product),
      onToggleFavorite: () => _run(
        () => ref
            .read(databaseProvider)
            .productsDao
            .setFavorite(product.id, favorite: !product.isFavorite),
      ),
    );

    return ListView(
      // Room for the floating button over the last product.
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 88),
      children: [
        if (favorite != null) productTile(favorite),
        if (others.isNotEmpty) ...[
          _SectionHeader(
            key: const ValueKey('saved'),
            title: l10n.productsSaved,
            collapsed: savedCollapsed,
            onToggle: () =>
                _run(() => settings.setSavedProductsCollapsed(!savedCollapsed)),
          ),
          if (!savedCollapsed) ...others.map(productTile),
        ],
        if (scans.isNotEmpty) ...[
          _SectionHeader(
            key: const ValueKey('scans'),
            title: l10n.productsRecentScans,
            collapsed: scansCollapsed,
            onToggle: () =>
                _run(() => settings.setRecentScansCollapsed(!scansCollapsed)),
          ),
          if (!scansCollapsed)
            for (final scan in scans)
              _ScanTile(scan: scan, onDelete: () => _deleteScan(scan)),
        ],
      ],
    );
  }
}

/// Title of a list of the tab, tapped to fold or unfold it.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    super.key,
    required this.title,
    required this.collapsed,
    required this.onToggle,
  });

  final String title;
  final bool collapsed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Semantics(
      button: true,
      expanded: !collapsed,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall!
                      .copyWith(color: colors.textSecondary),
                ),
              ),
              Icon(
                collapsed ? LucideIcons.chevronRight : LucideIcons.chevronDown,
                size: 18,
                color: colors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Product scanned and not saved yet, with what Open Food Facts said of
/// it. Tap it to save it as a product, tap its "+" button to add it to the
/// day, swipe it to delete it.
class _ScanTile extends StatelessWidget {
  const _ScanTile({required this.scan, required this.onDelete});

  final ScannedProduct scan;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final protein = scan.proteinPer100;
    final serving = scan.servingQuantity;
    final details = protein == null
        ? l10n.scanProteinUnknown
        : [
            l10n.productPerReference(
              formatProtein(protein, l10n.localeName),
              formatQuantity(l10n, 100, scan.unit),
            ),
            if (serving != null)
              l10n.productPortion(formatQuantity(l10n, serving, scan.unit)),
          ].join(' · ');

    return SwipeToDelete(
      key: ValueKey(scan.barcode),
      onDelete: onDelete,
      child: Material(
        color: colors.background,
        child: InkWell(
          onTap: () => context.push(AppRoutes.newProductFromScan(scan.barcode)),
          child: Container(
            padding: const EdgeInsets.fromLTRB(2, 8, 12, 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.divider)),
            ),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 40,
                  child: Icon(
                    LucideIcons.scanBarcode,
                    size: 20,
                    color: colors.scan,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        scannedProductName(scan.name, scan.brands) ??
                            scan.barcode,
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
                SizedBox.square(
                  dimension: 32,
                  child: IconButton.filled(
                    onPressed: () =>
                        context.push(AppRoutes.newEntryFromScan(scan.barcode)),
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
    return PillTabs(
      labels: {
        ProductSort.alphabetical: l10n.sortAlphabetical,
        ProductSort.mostUsed: l10n.sortMostUsed,
        ProductSort.recentlyUsed: l10n.sortRecentlyUsed,
      },
      selected: sort,
      onChanged: onChanged,
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.showUses,
    required this.onDelete,
    required this.onToggleFavorite,
  });

  final Product product;
  final bool showUses;
  final VoidCallback onDelete;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final details = [
      describeProduct(l10n, product, withPortion: true),
      if (showUses) l10n.productUseCount(product.useCount),
    ].join(' · ');

    return SwipeToDelete(
      key: ValueKey(product.id),
      onDelete: onDelete,
      child: Material(
        color: colors.background,
        child: InkWell(
          onTap: () => context.push(AppRoutes.editProduct(product.id)),
          onLongPress: () => context.push(AppRoutes.copyProduct(product.id)),
          child: Container(
            padding: const EdgeInsets.fromLTRB(2, 8, 12, 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.divider)),
            ),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 40,
                  child: IconButton(
                    onPressed: onToggleFavorite,
                    tooltip: product.isFavorite
                        ? l10n.removeFavorite
                        : l10n.setFavorite,
                    isSelected: product.isFavorite,
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      LucideIcons.star,
                      size: 20,
                      color: colors.textSecondary,
                    ),
                    // Lucide has no filled icons: the favorite uses the
                    // Material star, filled with the accent.
                    selectedIcon: const Icon(
                      Icons.star_rounded,
                      size: 26,
                      color: AppColors.accent,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyLarge!.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Its marks first, barcode then creatine, apart like
                      // the rest of the description.
                      Text.rich(
                        TextSpan(
                          children: [
                            for (final (index, part) in [
                              if (product.barcode != null)
                                _mark(
                                  Semantics(
                                    label: l10n.productBarcodeMark,
                                    excludeSemantics: true,
                                    child: Icon(
                                      LucideIcons.barcode,
                                      size: 14,
                                      color: colors.scan,
                                    ),
                                  ),
                                ),
                              if (product.creatineDoses > 0)
                                _mark(
                                  CreatineMark(
                                    doses: product.creatineDoses,
                                    weight: FontWeight.w400,
                                  ),
                                ),
                              TextSpan(text: details),
                            ].indexed) ...[
                              if (index > 0) const TextSpan(text: ' · '),
                              part,
                            ],
                          ],
                        ),
                        style: textTheme.bodySmall,
                      ),
                      if (product.activeRoutineMinutes case final minutes?)
                        _RoutineLabel(
                          routine: product.routine,
                          minutes: minutes,
                        ),
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
    );
  }
}

/// [mark] in the description of a product, centered on its line.
WidgetSpan _mark(Widget mark) =>
    WidgetSpan(alignment: PlaceholderAlignment.middle, child: mark);

/// Daily routine of a product: a reminder or an automatic addition, and its
/// time.
class _RoutineLabel extends StatelessWidget {
  const _RoutineLabel({required this.routine, required this.minutes});

  final DailyRoutine routine;
  final int minutes;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final color = AppColors.of(context).accentText;
    final time = formatTime(
      routineTimeOn(DateTime(2000), minutes),
      context.localeName,
    );
    final reminder = routine == DailyRoutine.reminder;

    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Icon(
            reminder ? LucideIcons.bell : LucideIcons.repeat,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              reminder
                  ? l10n.productRoutineReminder(time)
                  : l10n.productRoutineAutoAdd(time),
              style: Theme.of(context).textTheme.bodySmall!
                  .copyWith(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
