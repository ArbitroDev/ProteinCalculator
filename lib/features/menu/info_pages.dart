import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:protein_calculator/core/backup.dart';
import 'package:protein_calculator/core/crash_reporting.dart';
import 'package:protein_calculator/core/providers.dart';
import 'package:protein_calculator/core/theme.dart';
import 'package:protein_calculator/core/widgets/content_width.dart';
import 'package:protein_calculator/core/widgets/user_action.dart';
import 'package:protein_calculator/features/menu/github_link.dart';
import 'package:protein_calculator/l10n/app_localizations.dart';

/// Data and privacy page of the menu: where the data lives, and how to
/// export it to a file or import a backup.
class DataPrivacyPage extends ConsumerStatefulWidget {
  const DataPrivacyPage({super.key});

  @override
  ConsumerState<DataPrivacyPage> createState() => _DataPrivacyPageState();
}

class _DataPrivacyPageState extends ConsumerState<DataPrivacyPage> {
  bool _busy = false;

  /// Runs an export or an import, one at a time, telling the user if it
  /// fails.
  Future<void> _run(Future<void> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    await runUserAction(messenger, l10n, action);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _export() => _run(() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final now = ref.read(clockProvider)();
    final json = await exportBackup(ref.read(databaseProvider), now);
    final saved = await FilePicker.saveFile(
      fileName: backupFileName(now),
      bytes: utf8.encode(json),
      mimeType: 'application/json',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (saved != null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.exportDone)));
    }
  });

  Future<void> _import() => _run(() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (file == null) return;

    final Backup backup;
    try {
      backup = parseBackup(utf8.decode(await file.readAsBytes()));
    } on Exception catch (error) {
      // Not text, or not a backup. Anything else, such as a file that cannot
      // be read, is an unexpected error.
      if (error is! FormatException && error is! InvalidBackupException) {
        rethrow;
      }
      messenger.showSnackBar(SnackBar(content: Text(l10n.importInvalid)));
      return;
    }
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.importConfirmTitle),
        content: Text(
          l10n.importConfirmBody(
            l10n.backupEntryCount(backup.entries.length),
            l10n.backupProductCount(backup.products.length),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.importConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await restoreBackup(ref.read(databaseProvider), backup);
    messenger.showSnackBar(SnackBar(content: Text(l10n.importDone)));
  });

  Future<void> _setCrashReports(bool enabled) async {
    final saved = await runUserAction(
      ScaffoldMessenger.of(context),
      AppLocalizations.of(context),
      () async {
        await ref.read(databaseProvider).settingsDao.setCrashReports(enabled);
        return true;
      },
    );
    if (saved != null) await setCrashReporting(enabled);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colors = AppColors.of(context);
    final crashReports = ref.watch(crashReportsProvider).value;

    return _InfoScaffold(
      title: l10n.menuPrivacy,
      paragraphs: [l10n.privacyLocal, l10n.privacyBackup],
      footer: [
        if (crashReportingAvailable) ...[
          Text(l10n.crashReportsTitle, style: textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            l10n.crashReportsBody,
            style: textTheme.bodyLarge!.copyWith(
              fontSize: 14,
              color: colors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Material(
            color: colors.surface,
            borderRadius: BorderRadius.circular(14),
            child: SwitchListTile(
              value: crashReports ?? false,
              onChanged: crashReports == null ? null : _setCrashReports,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              title: Text(
                l10n.crashReportsToggle,
                style: textTheme.bodyLarge!.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
        Text(l10n.backupTitle, style: textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(
          l10n.backupBody,
          style: textTheme.bodyLarge!.copyWith(
            fontSize: 14,
            color: AppColors.of(context).textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 10),
        _ActionTile(
          icon: LucideIcons.download,
          label: l10n.exportData,
          onTap: _busy ? null : _export,
        ),
        _ActionTile(
          icon: LucideIcons.upload,
          label: l10n.importData,
          onTap: _busy ? null : _import,
        ),
      ],
    );
  }
}

/// About page of the menu.
class AboutPage extends ConsumerWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final version = ref.watch(appVersionProvider).value;

    return _InfoScaffold(
      title: l10n.menuAbout,
      header: [
        Text(l10n.appTitle, style: textTheme.displaySmall),
        if (version != null) Text(l10n.appVersion(version)),
      ],
      paragraphs: [
        l10n.aboutDescription,
        l10n.aboutLicense,
        l10n.aboutContribute,
      ],
      footer: const [GitHubLink()],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(icon, size: 22, color: colors.accentText),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyLarge!
                        .copyWith(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoScaffold extends StatelessWidget {
  const _InfoScaffold({
    required this.title,
    required this.paragraphs,
    this.header = const [],
    this.footer = const [],
  });

  final String title;
  final List<Widget> header;
  final List<String> paragraphs;
  final List<Widget> footer;

  @override
  Widget build(BuildContext context) {
    final body = Theme.of(context).textTheme.bodyLarge!
        .copyWith(fontSize: 14, height: 1.55);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => context.pop(),
        ),
        title: Text(title),
      ),
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
          children: [
            ...header,
            if (header.isNotEmpty) const SizedBox(height: 18),
            for (final paragraph in paragraphs)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Text(paragraph, style: body),
              ),
            if (footer.isNotEmpty) ...[const SizedBox(height: 10), ...footer],
          ],
        ),
      ),
    );
  }
}
