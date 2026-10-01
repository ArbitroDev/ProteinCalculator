import 'package:flutter/material.dart';
import 'package:protein_calculator/core/domain/day_slot.dart';

const _titleFont = 'Saira Semi Condensed';
const _bodyFont = 'Outfit';

/// Colors of the visual identity that Material's color scheme has no slot
/// for. Read them with `AppColors.of(context)`.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.text,
    required this.textSecondary,
    required this.divider,
    required this.structure,
    required this.shakerInside,
    required this.accentText,
  });

  final Color background;
  final Color surface;
  final Color surfaceRaised;
  final Color text;
  final Color textSecondary;
  final Color divider;

  /// Outline and graduations of the shaker.
  final Color structure;

  /// Empty part of the shaker and of the stacked bars.
  final Color shakerInside;

  /// Orange readable as text on the background.
  final Color accentText;

  static const accent = Color(0xFFFF8A3D);
  static const onAccent = Color(0xFF1B0E05);
  static const danger = Color(0xFFFF5C7A);
  static const cobalt = Color(0xFF2D3FE0);

  static const light = AppColors(
    background: Color(0xFFD9E3FF),
    surface: Color(0xFFEEF2FF),
    surfaceRaised: Color(0xFFFFFFFF),
    text: Color(0xFF0F1A66),
    textSecondary: Color(0xFF4A5699),
    divider: Color(0xFFC2CFFA),
    structure: Color(0xFF2D3FE0),
    shakerInside: Color(0xFFEEF2FF),
    accentText: Color(0xFFB8440F),
  );

  static const dark = AppColors(
    background: Color(0xFF0B1050),
    surface: Color(0xFF1A1E5A),
    surfaceRaised: Color(0xFF282D65),
    text: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF9EA7F0),
    divider: Color(0xFF282D65),
    structure: Color(0xFF6F7CFF),
    shakerInside: Color(0xFF1C215C),
    accentText: Color(0xFFFF8A3D),
  );

  /// Color of the entries added during [slot].
  static Color slot(DaySlot slot) => switch (slot) {
    DaySlot.morning => const Color(0xFFFFC59E),
    DaySlot.afternoon => const Color(0xFFFF8A3D),
    DaySlot.evening => const Color(0xFFD9531A),
  };

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>()!;

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceRaised,
    Color? text,
    Color? textSecondary,
    Color? divider,
    Color? structure,
    Color? shakerInside,
    Color? accentText,
  }) => AppColors(
    background: background ?? this.background,
    surface: surface ?? this.surface,
    surfaceRaised: surfaceRaised ?? this.surfaceRaised,
    text: text ?? this.text,
    textSecondary: textSecondary ?? this.textSecondary,
    divider: divider ?? this.divider,
    structure: structure ?? this.structure,
    shakerInside: shakerInside ?? this.shakerInside,
    accentText: accentText ?? this.accentText,
  );

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      background: mix(background, other.background),
      surface: mix(surface, other.surface),
      surfaceRaised: mix(surfaceRaised, other.surfaceRaised),
      text: mix(text, other.text),
      textSecondary: mix(textSecondary, other.textSecondary),
      divider: mix(divider, other.divider),
      structure: mix(structure, other.structure),
      shakerInside: mix(shakerInside, other.shakerInside),
      accentText: mix(accentText, other.accentText),
    );
  }
}

abstract final class AppTheme {
  static final ThemeData light = _build(AppColors.light, Brightness.light);
  static final ThemeData dark = _build(AppColors.dark, Brightness.dark);

  static ThemeData _build(AppColors colors, Brightness brightness) {
    TextStyle title(double size, FontWeight weight) => TextStyle(
      fontFamily: _titleFont,
      fontSize: size,
      fontWeight: weight,
      height: 1.1,
      color: colors.text,
    );
    TextStyle body(double size, FontWeight weight, Color color) => TextStyle(
      fontFamily: _bodyFont,
      fontSize: size,
      fontWeight: weight,
      color: color,
    );

    final textTheme = TextTheme(
      displayLarge: title(60, FontWeight.w800).copyWith(height: 0.9),
      displayMedium: title(46, FontWeight.w800),
      displaySmall: title(40, FontWeight.w800),
      headlineSmall: title(24, FontWeight.w700),
      titleMedium: title(17, FontWeight.w600),
      titleSmall: title(15, FontWeight.w600),
      bodyLarge: body(15, FontWeight.w400, colors.text),
      bodyMedium: body(13, FontWeight.w400, colors.text),
      bodySmall: body(12, FontWeight.w400, colors.textSecondary),
      labelLarge: body(14, FontWeight.w600, AppColors.onAccent),
      labelSmall: body(11, FontWeight.w500, colors.textSecondary),
    );

    final radius = BorderRadius.circular(10);

    return ThemeData(
      brightness: brightness,
      fontFamily: _bodyFont,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: AppColors.accent,
        onPrimary: AppColors.onAccent,
        secondary: colors.structure,
        onSecondary: AppColors.light.surfaceRaised,
        error: AppColors.danger,
        onError: AppColors.light.surfaceRaised,
        surface: colors.background,
        onSurface: colors.text,
        onSurfaceVariant: colors.textSecondary,
        outline: colors.divider,
      ),
      scaffoldBackgroundColor: colors.background,
      textTheme: textTheme,
      extensions: [colors],
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        foregroundColor: colors.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.headlineSmall,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.onAccent,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.accentText,
          textStyle: body(14, FontWeight.w600, colors.accentText),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        hintStyle: body(15, FontWeight.w400, colors.textSecondary),
        suffixStyle: body(15, FontWeight.w400, colors.textSecondary),
        errorStyle: body(12, FontWeight.w500, colors.accentText),
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: colors.accentText, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: colors.accentText, width: 1.5),
        ),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.accent,
        selectionHandleColor: AppColors.accent,
      ),
      dividerTheme: DividerThemeData(color: colors.divider, thickness: 1),
      // Snack bars use the inverse surface: navy on the light theme, white
      // on the dark one.
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: brightness == Brightness.light
            ? AppColors.light.text
            : AppColors.light.surfaceRaised,
        contentTextStyle: body(
          15,
          FontWeight.w400,
          brightness == Brightness.light
              ? AppColors.light.surfaceRaised
              : AppColors.dark.background,
        ),
        actionTextColor: brightness == Brightness.light
            ? AppColors.accent
            : AppColors.light.accentText,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
