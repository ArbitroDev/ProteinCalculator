import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:protein_calculator/core/app_settings.dart';
import 'package:protein_calculator/core/domain/barcode.dart';
import 'package:protein_calculator/core/theme.dart';
import 'package:protein_calculator/l10n/app_localizations.dart';

/// Full screen camera reading the barcode of a food product. Closes on the
/// first valid code, giving it back in its stored form (see
/// `normalizeBarcode`) to the page that opened it. The code can also be
/// typed. The picture is read on the phone and never leaves it.
class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

/// Why the camera shows nothing.
enum _CameraProblem { denied, unavailable }

class _ScanPageState extends State<ScanPage> with WidgetsBindingObserver {
  /// The barcodes of food products: nothing else is looked for, so nothing
  /// else is taken for one.
  static const _formats =
      Format.ean13 | Format.ean8 | Format.upca | Format.upce;

  CameraController? _camera;
  bool _torch = false;
  bool _torchAvailable = true;
  _CameraProblem? _problem;

  /// Increases to open the camera again, once allowed in the settings.
  int _attempt = 0;

  /// Whether the user left the app, maybe for its settings. Asking for the
  /// camera only makes it inactive: it is not opened again then.
  bool _wentAway = false;

  /// Whether a code was read: the next ones are ignored while the page
  /// closes.
  bool _done = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden || AppLifecycleState.paused:
        _wentAway = true;
      case AppLifecycleState.resumed:
        // Back from the settings, where the camera may have been allowed.
        if (_wentAway && _problem == _CameraProblem.denied) {
          setState(() {
            _problem = null;
            _attempt++;
          });
        }
        _wentAway = false;
      case AppLifecycleState.inactive || AppLifecycleState.detached:
        break;
    }
  }

  void _onCamera(CameraController? camera, Exception? error) {
    if (!mounted) return;
    setState(() {
      _camera = camera;
      _torch = false;
      if (error case CameraException(:final code)) {
        // Another request, made while the camera opens again, is not a
        // refusal.
        if (code == 'CameraPermissionsRequestOngoing') return;
        _problem = code == 'CameraAccessDenied'
            ? _CameraProblem.denied
            : _CameraProblem.unavailable;
      } else if (error != null) {
        _problem = _CameraProblem.unavailable;
      }
    });
  }

  void _onScan(Code code) {
    final text = code.text;
    if (_done || text == null) return;
    // A UPC-E is the short form of a UPC-A, which products are known by.
    final upcA = code.format == Format.upce ? expandUpcE(text) : null;
    final barcode = normalizeBarcode(upcA ?? text);
    if (barcode != null) _close(barcode);
  }

  void _close(String barcode) {
    _done = true;
    unawaited(HapticFeedback.mediumImpact());
    context.pop(barcode);
  }

  Future<void> _toggleTorch() async {
    final camera = _camera;
    if (camera == null) return;
    final on = !_torch;
    try {
      await camera.setFlashMode(on ? FlashMode.torch : FlashMode.off);
      if (mounted) setState(() => _torch = on);
    } on CameraException catch (error) {
      // Some phones say they have a torch they cannot light. Other errors
      // come from a camera closing with the app, opened again on return.
      if (error.code == 'setFlashModeFailed' && mounted) {
        setState(() => _torchAvailable = false);
      }
    }
  }

  Future<void> _typeCode() async {
    final barcode = await showDialog<String>(
      context: context,
      builder: (context) => const _BarcodeDialog(),
    );
    if (barcode != null && mounted && !_done) _close(barcode);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final problem = _problem;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (problem == null)
              Theme(
                // Color of the frame the reader draws.
                data: Theme.of(context)
                    .copyWith(primaryColor: AppColors.scanFrame),
                child: ReaderWidget(
                  key: ValueKey(_attempt),
                  codeFormat: _formats,
                  onScan: _onScan,
                  onControllerCreated: _onCamera,
                  showFlashlight: false,
                  showGallery: false,
                  showToggleCamera: false,
                  // Wide enough for a long barcode held close.
                  cropPercent: 0.8,
                  // The reader waits a second between two tries by default.
                  scanDelay: const Duration(milliseconds: 100),
                ),
              )
            else
              _CameraMessage(problem: problem),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _RoundButton(
                          icon: LucideIcons.x,
                          tooltip: l10n.close,
                          onPressed: () => context.pop(),
                        ),
                        const Spacer(),
                        if (problem == null &&
                            _camera != null &&
                            _torchAvailable)
                          _RoundButton(
                            icon: _torch
                                ? LucideIcons.flashlightOff
                                : LucideIcons.flashlight,
                            tooltip: _torch
                                ? l10n.scanTorchOff
                                : l10n.scanTorchOn,
                            selected: _torch,
                            onPressed: _toggleTorch,
                          ),
                      ],
                    ),
                    const Spacer(),
                    if (problem == null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          l10n.scanHint,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge!
                              .copyWith(color: Colors.white),
                        ),
                      ),
                    FilledButton.icon(
                      onPressed: _typeCode,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.black54,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 48),
                      ),
                      icon: const Icon(LucideIcons.keyboard, size: 20),
                      label: Text(l10n.scanTypeCode),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Round button over the camera picture, lit up when [selected].
class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) => IconButton.filled(
    onPressed: onPressed,
    tooltip: tooltip,
    isSelected: selected,
    style: IconButton.styleFrom(
      backgroundColor: selected ? AppColors.scanFrame : Colors.black54,
      foregroundColor: selected ? Colors.black : Colors.white,
      minimumSize: const Size.square(48),
    ),
    icon: Icon(icon),
  );
}

/// Why the camera shows nothing, in place of its picture, with the way to
/// allow it if it was refused.
class _CameraMessage extends StatelessWidget {
  const _CameraMessage({required this.problem});

  final _CameraProblem problem;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.cameraOff, size: 40, color: Colors.white),
            const SizedBox(height: 16),
            Text(
              switch (problem) {
                _CameraProblem.denied => l10n.scanCameraDenied,
                _CameraProblem.unavailable => l10n.scanCameraUnavailable,
              },
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge!
                  .copyWith(color: Colors.white),
            ),
            if (problem == _CameraProblem.denied) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: openAppSettings,
                child: Text(l10n.openSettings),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Asks for the digits under the barcode, and gives back the code in its
/// stored form once its check digit is right.
class _BarcodeDialog extends StatefulWidget {
  const _BarcodeDialog();

  @override
  State<_BarcodeDialog> createState() => _BarcodeDialogState();
}

class _BarcodeDialogState extends State<_BarcodeDialog> {
  final _code = TextEditingController();
  bool _invalid = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _submit() {
    final barcode = normalizeBarcode(_code.text);
    if (barcode == null) {
      setState(() => _invalid = true);
    } else {
      Navigator.of(context).pop(barcode);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.scanTypeTitle),
      content: TextField(
        controller: _code,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(13),
        ],
        onChanged: (_) {
          if (_invalid) setState(() => _invalid = false);
        },
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          hintText: l10n.scanTypeHint,
          errorText: _invalid ? l10n.scanTypeInvalid : null,
          errorMaxLines: 3,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.scanTypeConfirm)),
      ],
    );
  }
}
