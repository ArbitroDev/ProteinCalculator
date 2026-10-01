import 'dart:math';

import 'package:flutter/material.dart';
import 'package:protein_calculator/core/domain/day_slot.dart';
import 'package:protein_calculator/core/theme.dart';

/// Horizontal bar of a day's protein, one segment per part of the day.
/// Its full length is the daily [goal].
class StackedBar extends StatelessWidget {
  const StackedBar({
    super.key,
    required this.bySlot,
    required this.goal,
    this.height = 8,
  });

  final Map<DaySlot, double> bySlot;
  final double goal;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final total = bySlot.values.fold(0.0, (sum, grams) => sum + grams);
    final filled = goal <= 0 ? 1.0 : min(total, goal) / goal;

    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: Container(
          height: height,
          color: colors.shakerInside,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth * filled;
              final slots = [
                for (final slot in DaySlot.values)
                  if ((bySlot[slot] ?? 0) > 0) slot,
              ];
              return Row(
                children: [
                  for (final (index, slot) in slots.indexed)
                    Container(
                      width: total == 0 ? 0 : width * bySlot[slot]! / total,
                      decoration: BoxDecoration(
                        color: AppColors.slot(slot),
                        border: index == 0
                            ? null
                            : Border(
                                left: BorderSide(
                                  color: colors.background,
                                  width: 1.5,
                                ),
                              ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
