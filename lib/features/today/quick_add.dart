import 'dart:async';
import 'dart:math';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/database/protein_amounts.dart';
import 'package:protein_calculator/core/formatting.dart';
import 'package:protein_calculator/core/theme.dart';
import 'package:protein_calculator/l10n/app_localizations.dart';

/// Button adding one portion of the favorite [product] at once.
class QuickAddButton extends StatefulWidget {
  const QuickAddButton({
    super.key,
    required this.product,
    required this.locale,
    required this.onPressed,
  });

  final Product product;
  final String locale;

  /// Receives the global position the animation starts from: where the
  /// button was touched, or its center when pressed otherwise.
  final ValueChanged<Offset> onPressed;

  @override
  State<QuickAddButton> createState() => _QuickAddButtonState();
}

class _QuickAddButtonState extends State<QuickAddButton> {
  /// Where the last touch went down, until the press it makes.
  Offset? _touch;

  void _press() {
    final box = context.findRenderObject() as RenderBox?;
    final from =
        _touch ??
        box?.localToGlobal(box.size.center(Offset.zero)) ??
        Offset.zero;
    _touch = null;
    widget.onPressed(from);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final product = widget.product;
    final grams = l10n.grams(
      formatProtein(product.amount.proteinGrams, widget.locale),
    );

    // As wide as its content, under the summary: the name on one line, cut
    // when too long, and the grams always shown after it.
    return Listener(
      onPointerDown: (event) => _touch = event.position,
      child: Tooltip(
        message: l10n.quickAdd(product.name),
        child: FilledButton(
          onPressed: _press,
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 52),
            padding: const EdgeInsets.fromLTRB(14, 10, 18, 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.plus, size: 24),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelLarge!.copyWith(fontSize: 16),
                ),
              ),
              Text(
                ' · $grams',
                style: textTheme.labelLarge!.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Throws a star of [color] from [from], a global position, into the mouth
/// of the shaker held by [shaker], above everything shown in [context], and
/// completes when it lands.
Future<void> flyToShaker(
  BuildContext context, {
  required Offset from,
  required GlobalKey shaker,
  required Color color,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  final overlayBox = overlay.context.findRenderObject() as RenderBox?;
  final shakerBox = shaker.currentContext?.findRenderObject() as RenderBox?;
  if (overlayBox == null || shakerBox == null) {
    return Future.value();
  }

  final start = overlayBox.globalToLocal(from);
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
