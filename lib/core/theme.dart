import 'package:flutter/material.dart';

/// Placeholder theme until the visual identity is defined.
abstract final class AppTheme {
  static const _seed = Color(0xFF2E7D6B);

  static final ThemeData light = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: _seed),
  );

  static final ThemeData dark = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
    ),
  );
}
