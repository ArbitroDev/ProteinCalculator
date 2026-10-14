import 'package:flutter/services.dart';

const _settings = MethodChannel('protein_calculator/settings');

/// Opens the page of the app in the Android settings, where the user allows
/// what was refused, such as the camera.
Future<void> openAppSettings() =>
    _settings.invokeMethod<void>('openAppSettings');
