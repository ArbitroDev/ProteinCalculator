import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:protein_calculator/core/daily_routines.dart';
import 'package:protein_calculator/core/theme.dart';
import 'package:protein_calculator/l10n/app_localizations.dart';

/// Tells that notifications of the daily routines are turned off, or late
/// without the permission of exact times ([late]), with a button opening
/// their settings in Android.
class NotificationsOff extends ConsumerWidget {
  const NotificationsOff({super.key, required this.message, this.late = false});

  final String message;
  final bool late;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            late ? LucideIcons.alarmClockOff : LucideIcons.bellOff,
            size: 18,
            color: colors.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall!
                  .copyWith(color: colors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              final status = ref.read(notificationStatusProvider.notifier);
              late
                  ? unawaited(status.requestExactAlarms())
                  : unawaited(status.openSettings());
            },
            child: Text(l10n.openSettings),
          ),
        ],
      ),
    );
  }
}
