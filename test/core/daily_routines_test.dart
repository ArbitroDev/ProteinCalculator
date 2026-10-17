import 'package:flutter_test/flutter_test.dart';
import 'package:protein_calculator/core/daily_routines.dart';
import 'package:protein_calculator/core/domain/daily_routine.dart';
import 'package:protein_calculator/core/domain/protein_amount.dart';

import '../helpers.dart';

void main() {
  test('a creatine-only auto-add fills no part of the day', () async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final now = DateTime(2026, 10, 1, 7);
    Future<void> autoAdd(String name, double protein, int doses) async {
      final id = await db.productsDao.insertProduct(
        name: name,
        amount: DirectAmount(protein),
        createdAt: DateTime(2026, 9),
        creatineDoses: doses,
      );
      await db.productsDao.setRoutine(
        id,
        DailyRoutine.autoAdd,
        minutes: 8 * 60,
        now: now,
      );
    }

    await autoAdd('Creatine', 0, 1);
    await autoAdd('Skyr', 15, 0);

    final routines = slotFillingAutoAdds(await db.productsDao.getAutoAdds());

    expect(routines, [(minutes: 8 * 60, checkedAt: now)]);
  });
}
