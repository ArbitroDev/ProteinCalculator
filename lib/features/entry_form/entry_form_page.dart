import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:protein_calculator/l10n/app_localizations.dart';

/// Form to add an entry. Its fields come with the next development step.
class EntryFormPage extends StatelessWidget {
  const EntryFormPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.x),
          tooltip: l10n.close,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(l10n.newEntryTitle),
      ),
    );
  }
}
