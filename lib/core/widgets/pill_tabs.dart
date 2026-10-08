import 'package:flutter/material.dart';
import 'package:protein_calculator/core/theme.dart';
import 'package:protein_calculator/core/widgets/sliding_selector.dart';

/// Options of equal width in a pill, the selected one on a sliding pill:
/// the look of the tab bar, for the sorts of the products and the views of
/// the history.
class PillTabs<T> extends StatelessWidget {
  const PillTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  /// Options and their labels, in order.
  final Map<T, String> labels;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final style = Theme.of(context).textTheme.bodyMedium!;
    final options = labels.keys.toList();

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: ShapeDecoration(
        color: colors.surface,
        shape: StadiumBorder(side: BorderSide(color: colors.divider)),
      ),
      child: SlidingSelector(
        selectedIndex: options.indexOf(selected),
        gap: 4,
        shape: const StadiumBorder(),
        children: [
          for (final value in options)
            Semantics(
              button: true,
              selected: value == selected,
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
                        color: value == selected
                            ? AppColors.onAccent
                            : colors.textSecondary,
                        fontWeight: value == selected
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
