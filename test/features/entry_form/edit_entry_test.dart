import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protein_calculator/core/domain/entry_mode.dart';
import 'package:protein_calculator/core/providers.dart';
import 'package:protein_calculator/features/entry_form/entry_form_notifier.dart';
import 'package:protein_calculator/features/entry_form/entry_form_state.dart';

import '../../helpers.dart';

void main() {
  test('editing an entry updates it instead of adding one', () async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final id = await db.entriesDao.insertEntry(
      name: 'Skyr',
      mode: EntryMode.direct,
      proteinGrams: 15,
      createdAt: DateTime(2026, 10, 1, 8),
    );
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 1, 9)),
      ],
    );
    addTearDown(container.dispose);
    final args = EntryFormArgs.editEntry(id);
    final sub = container.listen(entryFormProvider(args), (_, _) {});
    addTearDown(sub.close);

    await container.read(entryFormProvider(args).future);
    final notifier = container.read(entryFormProvider(args).notifier);
    notifier.setProtein('20');
    expect(await notifier.submit(), isTrue);

    final entries = await db.entriesDao.watchDayEntries(20261001).first;
    expect(entries.map((e) => (e.id, e.proteinGrams)), [(id, 20.0)]);
  });
}
