import 'package:flutter/material.dart';
import 'package:protein_calculator/core/theme.dart';
import 'package:protein_calculator/l10n/app_localizations.dart';

/// How long a deleted item can be restored.
const undoDuration = Duration(seconds: 3);

/// Shows "[label] — Undo" for a few seconds, with a ring emptying while the
/// deletion can still be undone.
void showUndoSnackBar(
  ScaffoldMessengerState messenger, {
  required AppLocalizations l10n,
  required String label,
  required VoidCallback onUndo,
}) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: undoDuration,
        persist: false,
        content: _UndoCountdown(label: label),
        action: SnackBarAction(label: l10n.undo, onPressed: onUndo),
      ),
    );
}

class _UndoCountdown extends StatelessWidget {
  const _UndoCountdown({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final track = DefaultTextStyle.of(context).style.color
        ?.withValues(alpha: 0.2);
    return Row(
      children: [
        SizedBox.square(
          dimension: 20,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 1, end: 0),
            duration: undoDuration,
            builder: (context, value, _) => CircularProgressIndicator(
              value: value,
              strokeWidth: 3,
              color: AppColors.accent,
              backgroundColor: track,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label)),
      ],
    );
  }
}
