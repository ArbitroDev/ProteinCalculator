import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:protein_calculator/core/theme.dart';
import 'package:protein_calculator/core/widgets/undo_snack_bar.dart';
import 'package:protein_calculator/core/widgets/user_action.dart';
import 'package:protein_calculator/l10n/app_localizations.dart';

/// Row of a list deleted by swiping it to the left, or with the "delete"
/// action of screen readers.
class SwipeToDelete extends StatelessWidget {
  const SwipeToDelete({
    required super.key,
    required this.onDelete,
    required this.child,
  });

  final VoidCallback onDelete;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    customSemanticsActions: {
      CustomSemanticsAction(label: AppLocalizations.of(context).delete):
          onDelete,
    },
    child: Dismissible(
      key: key!,
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        color: AppColors.danger,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        child: const Icon(LucideIcons.trash2, color: Colors.white),
      ),
      child: child,
    ),
  );
}

/// Deletion of the rows of a list, with a few seconds to undo it.
///
/// A deleted row is hidden at once, until the database confirms: if the
/// deletion fails, the row shows again.
mixin UndoableDeletion<W extends StatefulWidget> on State<W> {
  final _hidden = <int>{};

  /// Whether the row [id] was deleted and must not show.
  bool isDeleted(int id) => _hidden.contains(id);

  /// Deletes the row [id] with [delete], which returns what [restore] needs
  /// to put it back, or null if it was already gone; then offers to undo it
  /// with a message saying [label].
  Future<void> deleteWithUndo<T extends Object>({
    required int id,
    required Future<T?> Function() delete,
    required Future<void> Function(T deleted) restore,
    required String label,
  }) async {
    setState(() => _hidden.add(id));
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final deleted = await runUserAction(messenger, l10n, delete);
    if (deleted == null) {
      // Failed, or already gone: either way the list shows the truth again,
      // once a frame has removed the swiped row, which cannot come back
      // within the same frame.
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) setState(() => _hidden.remove(id));
      return;
    }
    showUndoSnackBar(
      messenger,
      l10n: l10n,
      label: label,
      onUndo: () async {
        await runUserAction(messenger, l10n, () => restore(deleted));
        if (mounted) setState(() => _hidden.remove(id));
      },
    );
  }
}
