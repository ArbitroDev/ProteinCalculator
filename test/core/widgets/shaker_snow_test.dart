import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protein_calculator/core/domain/day_slot.dart';
import 'package:protein_calculator/core/theme.dart';
import 'package:protein_calculator/core/widgets/shaker.dart';
import 'package:protein_calculator/core/widgets/snow.dart';

void main() {
  testWidgets('draws the snow of the lid as it falls and settles again', (
    tester,
  ) async {
    final motion = ShakerMotion();
    addTearDown(motion.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.christmasLight,
        home: Center(
          child: SizedBox(
            width: 110,
            height: 290,
            child: Shaker(
              layers: const [ShakerLayer(grams: 60, slot: DaySlot.afternoon)],
              goal: 120,
              semanticLabel: 'Shaker',
              snowy: true,
              motion: motion,
            ),
          ),
        ),
      ),
    );

    // Settled, falling at its start and its end, then settling again from
    // nothing.
    for (final (snow, fall) in [
      (1.0, null),
      (0.0, 0.0),
      (0.0, snowFallSeconds - 0.01),
      (0.0, null),
      (0.4, null),
    ]) {
      motion.update(
        tilt: 0,
        mix: 0,
        phase: 0,
        snow: snow,
        snowFall: fall,
        fallenSnow: 1,
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
  });
}
