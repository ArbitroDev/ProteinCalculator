import 'dart:async';
import 'dart:math';
import 'dart:ui' show lerpDouble;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/database/protein_amounts.dart';
import 'package:protein_calculator/core/formatting.dart';
import 'package:protein_calculator/core/providers.dart';
import 'package:protein_calculator/core/theme.dart';
import 'package:protein_calculator/l10n/app_localizations.dart';

/// The favorite product, added in one tap from the today screen.
final favoriteProductProvider = Provider<Product?>(
  (ref) => ref
      .watch(productsProvider)
      .value
      ?.firstWhereOrNull((product) => product.isFavorite),
);

/// Button adding one portion of the favorite [product] at once.
class QuickAddButton extends StatelessWidget {
  const QuickAddButton({
    super.key,
    required this.product,
    required this.locale,
    required this.onPressed,
  });

  final Product product;
  final String locale;

  /// Receives the button's context, where the animation starts from.
  final ValueChanged<BuildContext> onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final grams = l10n.grams(
      formatProtein(product.amount.proteinGrams, locale),
    );

    return ConstrainedBox(
      // Long names are cut rather than squeezing the summary.
      constraints: BoxConstraints(
        maxWidth: min(220, MediaQuery.sizeOf(context).width * 0.45),
      ),
      child: Tooltip(
        message: l10n.quickAdd(product.name),
        child: FilledButton(
          onPressed: () => onPressed(context),
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 72),
            padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.plus, size: 26),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Two lines, so most names show in full.
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelLarge!.copyWith(
                        fontSize: 14,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      grams,
                      style: textTheme.labelLarge!.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
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

/// Throws a star of [color] from [from] into the mouth of the shaker held
/// by [shaker], and completes when it lands.
Future<void> flyToShaker({
  required BuildContext from,
  required GlobalKey shaker,
  required Color color,
}) {
  final overlay = Overlay.of(from, rootOverlay: true);
  final overlayBox = overlay.context.findRenderObject() as RenderBox?;
  final fromBox = from.findRenderObject() as RenderBox?;
  final shakerBox = shaker.currentContext?.findRenderObject() as RenderBox?;
  if (overlayBox == null || fromBox == null || shakerBox == null) {
    return Future.value();
  }

  final start = overlayBox.globalToLocal(
    fromBox.localToGlobal(fromBox.size.center(Offset.zero)),
  );
  // The mouth of the shaker, just under the lid.
  final end = overlayBox.globalToLocal(
    shakerBox.localToGlobal(
      Offset(shakerBox.size.width / 2, shakerBox.size.height * 0.3),
    ),
  );
  // Arcs up before falling in.
  final control = Offset((start.dx + end.dx) / 2, min(start.dy, end.dy) - 60);

  final landed = Completer<void>();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInCubic,
        onEnd: () {
          entry.remove();
          landed.complete();
        },
        builder: (context, t, _) {
          final position =
              start * ((1 - t) * (1 - t)) +
              control * (2 * (1 - t) * t) +
              end * (t * t);
          final size = lerpDouble(46, 18, t)!;
          return Stack(
            children: [
              Positioned(
                left: position.dx - size / 2,
                top: position.dy - size / 2,
                width: size,
                height: size,
                // The favorite star, outlined so it shows on any background.
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.star_rounded,
                      size: size,
                      color: AppColors.onAccent,
                    ),
                    Icon(Icons.star_rounded, size: size * 0.8, color: color),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
  overlay.insert(entry);
  return landed.future;
}

/// Adds a portion of [product] now, without the form. Returns the id of the
/// new entry.
Future<int> quickAdd(WidgetRef ref, Product product) {
  return ref
      .read(databaseProvider)
      .entriesDao
      .insertEntry(
        name: product.name,
        amount: product.amount,
        createdAt: ref.read(clockProvider)(),
      );
}
