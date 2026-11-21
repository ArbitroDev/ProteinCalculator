import 'package:flutter/material.dart';
import 'package:protein_calculator/core/theme.dart';

/// Row, or column, of options of equal size, with a pill behind the
/// selected one that slides to the new selection.
class SlidingSelector extends StatelessWidget {
  const SlidingSelector({
    super.key,
    required this.selectedIndex,
    required this.shape,
    required this.children,
    this.gap = 0,
    this.direction = Axis.horizontal,
    this.color = AppColors.selection,
  });

  final int selectedIndex;

  /// Shape of the pill.
  final ShapeBorder shape;
  final List<Widget> children;

  /// Space between two options.
  final double gap;

  /// Whether the options are laid out in a row or in a column.
  final Axis direction;

  /// Color of the pill, which it takes on as it slides when it changes.
  final Color color;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 250);
    final horizontal = direction == Axis.horizontal;
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = children.length;
        final length = horizontal
            ? constraints.maxWidth
            : constraints.maxHeight;
        final size = (length - gap * (count - 1)) / count;
        final offset = selectedIndex * (size + gap);
        return Stack(
          children: [
            AnimatedPositioned(
              duration: duration,
              curve: Curves.easeOutCubic,
              left: horizontal ? offset : 0,
              top: horizontal ? 0 : offset,
              right: horizontal ? null : 0,
              bottom: horizontal ? 0 : null,
              width: horizontal ? size : null,
              height: horizontal ? null : size,
              child: AnimatedContainer(
                duration: duration,
                curve: Curves.easeOutCubic,
                decoration: ShapeDecoration(color: color, shape: shape),
              ),
            ),
            Flex(
              direction: direction,
              children: [
                for (final (index, child) in children.indexed) ...[
                  if (index > 0)
                    SizedBox(
                      width: horizontal ? gap : null,
                      height: horizontal ? null : gap,
                    ),
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
