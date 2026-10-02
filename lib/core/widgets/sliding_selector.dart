import 'package:flutter/material.dart';
import 'package:protein_calculator/core/theme.dart';

/// Row of options of equal width, with a pill behind the selected one that
/// slides to the new selection.
class SlidingSelector extends StatelessWidget {
  const SlidingSelector({
    super.key,
    required this.selectedIndex,
    required this.shape,
    required this.children,
    this.gap = 0,
  });

  final int selectedIndex;

  /// Shape of the pill.
  final ShapeBorder shape;
  final List<Widget> children;

  /// Space between two options.
  final double gap;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = children.length;
        final width = (constraints.maxWidth - gap * (count - 1)) / count;
        return Stack(
          children: [
            AnimatedPositioned(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              left: selectedIndex * (width + gap),
              top: 0,
              bottom: 0,
              width: width,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: AppColors.selection,
                  shape: shape,
                ),
              ),
            ),
            Row(
              children: [
                for (final (index, child) in children.indexed) ...[
                  if (index > 0) SizedBox(width: gap),
                  Expanded(child: child),
                ],
              ],
            ),
          ],
        );
      },
    );
  }
}
