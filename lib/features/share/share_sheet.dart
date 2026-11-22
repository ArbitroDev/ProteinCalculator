import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:protein_calculator/core/providers.dart';
import 'package:protein_calculator/core/theme.dart';
import 'package:protein_calculator/core/widgets/pill_tabs.dart';
import 'package:protein_calculator/core/widgets/user_action.dart';
import 'package:protein_calculator/l10n/app_localizations.dart';
import 'package:share_plus/share_plus.dart';

/// Side of a tile, in logical pixels.
const shareTileSize = 360.0;

/// Pixel ratio of the captured tile: a 1080 px square.
const shareTilePixelRatio = 3.0;

/// Shares a PNG image named [fileName]; [origin] places the share sheet on
/// tablets.
typedef ShareImage = Future<void> Function(
  Uint8List png,
  String fileName,
  Rect? origin,
);

/// Shares through the system share sheet; replaced in tests.
final shareImageProvider = Provider<ShareImage>(
  (ref) =>
      (png, fileName, origin) => SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(png, mimeType: 'image/png', name: fileName)],
          fileNameOverrides: [fileName],
          sharePositionOrigin: origin,
        ),
      ),
);

/// What a tile shows that the sheet lets change.
@immutable
class ShareOptions {
  const ShareOptions({
    this.showProducts = false,
    this.offset = 0,
    this.variant = 0,
  });

  /// Whether the names of the products show, on the timeline of a day.
  final bool showProducts;

  /// Steps back from the period first shown, such as months of a calendar.
  final int offset;

  /// Index of the variant chosen, of [ShareChoice.variants].
  final int variant;

  ShareOptions copyWith({bool? showProducts, int? offset, int? variant}) =>
      ShareOptions(
        showProducts: showProducts ?? this.showProducts,
        offset: offset ?? this.offset,
        variant: variant ?? this.variant,
      );
}

/// One tile offered in the share sheet.
@immutable
class ShareChoice {
  const ShareChoice({
    required this.label,
    required this.fileName,
    required this.build,
    this.productsSwitch = false,
    this.browse,
    this.variants,
  });

  /// Name of the tile in the choice, when the sheet offers several.
  final String label;

  /// Name of the shared file, without extension, for the options chosen.
  final String Function(ShareOptions options) fileName;
  final Widget Function(ShareOptions options) build;

  /// Whether the sheet offers to show the names of the products.
  final bool productsSwitch;

  /// Lets the sheet go back from the period first shown: the name of the
  /// period at an offset, and the furthest offset back.
  final ({String Function(int offset) name, int oldest})? browse;

  /// Names of the ways the tile can be drawn, such as what colors the days
  /// of a calendar, the first one shown; null for a single way.
  final List<String>? variants;
}

/// Opens the sheet previewing the tiles of [choices], the first one shown,
/// and shares the one chosen as a 1080 px image.
Future<void> showShareSheet(BuildContext context, List<ShareChoice> choices) =>
    showModalBottomSheet<void>(
      context: context,
      // Over the tab bar.
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      // Its content keeps clear of the Android navigation bar, the sheet
      // itself going under it.
      builder: (context) =>
          SafeArea(top: false, child: _ShareSheet(choices: choices)),
    );

class _ShareSheet extends ConsumerStatefulWidget {
  const _ShareSheet({required this.choices});

  final List<ShareChoice> choices;

  @override
  ConsumerState<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends ConsumerState<_ShareSheet> {
  final _tileKey = GlobalKey();
  final _buttonKey = GlobalKey();
  var _index = 0;

  /// Options of each choice, kept when going from one to another.
  final _optionsOf = <int, ShareOptions>{};
  var _sharing = false;

  ShareChoice get _choice => widget.choices[_index];
  ShareOptions get _options => _optionsOf[_index] ?? const ShareOptions();
  set _options(ShareOptions options) => _optionsOf[_index] = options;

  Future<void> _share() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final share = ref.read(shareImageProvider);
    final box = _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    setState(() => _sharing = true);
    try {
      await runUserAction(messenger, l10n, () async {
        final png = await captureTile(_tileKey);
        await share(png, '${_choice.fileName(_options)}.png', origin);
      });
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final browse = _choice.browse;
    final variants = _choice.variants;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.shareTitle, style: textTheme.headlineSmall),
              const SizedBox(height: 14),
              if (widget.choices.length > 1) ...[
                PillTabs<int>(
                  labels: {
                    for (final (index, choice) in widget.choices.indexed)
                      index: choice.label,
                  },
                  selected: _index,
                  onChanged: (index) => setState(() => _index = index),
                ),
                const SizedBox(height: 14),
              ],
              if (variants != null && variants.length > 1) ...[
                PillTabs<int>(
                  labels: {
                    for (final (index, label) in variants.indexed) index: label,
                  },
                  selected: _options.variant,
                  onChanged: (index) => setState(
                    () => _options = _options.copyWith(variant: index),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (browse != null) ...[
                Row(
                  children: [
                    IconButton(
                      tooltip: l10n.statsPrevious,
                      onPressed: _options.offset > browse.oldest
                          ? () => setState(
                              () => _options = _options.copyWith(
                                offset: _options.offset - 1,
                              ),
                            )
                          : null,
                      icon: const Icon(LucideIcons.chevronLeft),
                    ),
                    Expanded(
                      child: Text(
                        browse.name(_options.offset),
                        textAlign: TextAlign.center,
                        style: textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.statsNext,
                      onPressed: _options.offset < 0
                          ? () => setState(
                              () => _options = _options.copyWith(
                                offset: _options.offset + 1,
                              ),
                            )
                          : null,
                      icon: const Icon(LucideIcons.chevronRight),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              DecoratedBox(
                // The tile has the background of the sheet: an outline sets
                // it apart.
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.of(context).divider,
                    width: 1.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: FittedBox(
                      child: RepaintBoundary(
                        key: _tileKey,
                        child: ShareTileChristmas(
                          christmas: ref.watch(christmasActiveProvider),
                          child: _choice.build(_options),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (_choice.productsSwitch)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.shareShowProducts),
                  value: _options.showProducts,
                  onChanged: (value) => setState(
                    () => _options = _options.copyWith(showProducts: value),
                  ),
                ),
              const SizedBox(height: 14),
              FilledButton.icon(
                key: _buttonKey,
                onPressed: _sharing ? null : _share,
                icon: _sharing
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : const Icon(LucideIcons.share2),
                label: Text(l10n.shareImage),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The tile under [key], a [RepaintBoundary], as a 1080 px PNG.
Future<Uint8List> captureTile(GlobalKey key) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: shareTilePixelRatio);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

/// Dresses the tiles under it for Christmas, as the app is: red in place of
/// the orange, see [shareTileColors], snow on the shakers, the baubles of the
/// calendar. The share sheet puts it over the tiles while the Christmas
/// theme is on.
class ShareTileChristmas extends InheritedWidget {
  const ShareTileChristmas({
    super.key,
    required this.christmas,
    required super.child,
  });

  final bool christmas;

  /// Whether the tiles under [context] are dressed for Christmas.
  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<ShareTileChristmas>()
          ?.christmas ??
      false;

  @override
  bool updateShouldNotify(ShareTileChristmas oldWidget) =>
      oldWidget.christmas != christmas;
}

/// Colors of the tiles: the light ones whatever the theme, red for
/// Christmas, see [ShareTileChristmas].
AppColors shareTileColors(BuildContext context) =>
    ShareTileChristmas.of(context) ? AppColors.christmasLight : AppColors.light;

/// The square every tile is drawn in: the light colors whatever the theme,
/// no text scaling nor animation, and the logo with the name of the app at
/// the bottom.
class ShareTileFrame extends StatelessWidget {
  const ShareTileFrame({super.key, required this.child, this.accent = false});

  final Widget child;

  /// Background in the color of the app, orange or Christmas red, for the
  /// streak.
  final bool accent;

  /// Space around the content.
  static const padding = 27.0;

  @override
  Widget build(BuildContext context) {
    final christmas = ShareTileChristmas.of(context);
    final theme = christmas ? AppTheme.christmasLight : AppTheme.light;
    final colors = shareTileColors(context);
    final ink = accent ? colors.onAccent : colors.text;
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        disableAnimations: true,
        textScaler: TextScaler.noScaling,
        boldText: false,
      ),
      child: Theme(
        data: theme,
        child: SizedBox.square(
          dimension: shareTileSize,
          child: ColoredBox(
            color: accent ? colors.accent : colors.background,
            child: DefaultTextStyle(
              style: theme.textTheme.bodyMedium!.copyWith(color: ink),
              child: Padding(
                padding: const EdgeInsets.all(padding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: child),
                    const SizedBox(height: 10),
                    _Signature(
                      color: accent ? shareOnAccentSecondary(context) : null,
                      christmas: christmas,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Secondary text on the background of a tile in the color of the app: dark
/// on the orange, light on the Christmas red.
Color shareOnAccentSecondary(BuildContext context) =>
    ShareTileChristmas.of(context)
    ? const Color(0xFFFFE3E7)
    : const Color(0xFF5A2A08);

class _Signature extends StatelessWidget {
  const _Signature({this.color, required this.christmas});

  final Color? color;

  /// Whether the logo is the Christmas one, red.
  final bool christmas;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        SvgPicture.asset(
          christmas
              ? 'assets/branding/logo-christmas.svg'
              : 'assets/branding/logo.svg',
          width: 16,
          height: 16,
          excludeFromSemantics: true,
        ),
        const SizedBox(width: 7),
        Text(
          l10n.appTitle,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: color ?? AppColors.light.textSecondary,
          ),
        ),
      ],
    );
  }
}
