import 'package:flutter/material.dart';
import 'package:protein_calculator/app.dart';
import 'package:protein_calculator/core/backup.dart';
import 'package:protein_calculator/core/database/database_file.dart';
import 'package:protein_calculator/core/theme.dart';
import 'package:protein_calculator/core/widgets/content_width.dart';
import 'package:protein_calculator/core/widgets/pick_backup.dart';
import 'package:protein_calculator/core/widgets/user_action.dart';
import 'package:protein_calculator/l10n/app_localizations.dart';

/// Shown instead of the app when its data cannot be read at launch: the
/// user can try again, or start over from a backup.
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({
    super.key,
    required this.onRetry,
    required this.onRestore,
  });

  /// Tries again to start the app; completes with whether it started.
  final Future<bool> Function() onRetry;

  /// Sets the unreadable data aside and starts the app from [backup];
  /// completes with whether it started.
  final Future<bool> Function(Backup backup) onRestore;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      localeListResolutionCallback: resolveLocale,
      home: _StartupErrorPage(onRetry: onRetry, onRestore: onRestore),
    );
  }
}

class _StartupErrorPage extends StatefulWidget {
  const _StartupErrorPage({required this.onRetry, required this.onRestore});

  final Future<bool> Function() onRetry;
  final Future<bool> Function(Backup backup) onRestore;

  @override
  State<_StartupErrorPage> createState() => _StartupErrorPageState();
}

class _StartupErrorPageState extends State<_StartupErrorPage> {
  bool _busy = false;

  Future<void> _retry() => _attempt((_, _) => widget.onRetry());

  Future<void> _restore() => _attempt((messenger, l10n) async {
    final backup = await pickBackup(messenger, l10n);
    // Cancelled, or not a backup: nothing was set aside.
    if (backup == null) return null;
    return widget.onRestore(backup);
  });

  /// Runs [attempt], which completes with whether the app started, or null
  /// if nothing was tried. If the app still cannot start, this screen stays
  /// and says so.
  Future<void> _attempt(
    Future<bool?> Function(
      ScaffoldMessengerState messenger,
      AppLocalizations l10n,
    )
    attempt,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    final started = await runUserAction(
      messenger,
      l10n,
      () => attempt(messenger, l10n),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (started == false) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.startupStillFailing)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: ContentWidth(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.startupErrorTitle,
                  style: textTheme.headlineSmall!.copyWith(fontSize: 26),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.startupErrorBody,
                  style: textTheme.bodyLarge!.copyWith(
                    color: AppColors.of(context).textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: _busy ? null : _retry,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: Text(l10n.startupRetry),
                ),
                if (canSetAsideDatabase) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _busy ? null : _restore,
                    style: TextButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: Text(l10n.startupRestore),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
