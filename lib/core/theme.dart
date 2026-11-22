import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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
    required this.scan,
    required this.scanSurface,
    required this.creatineText,
    required this.hevy,
    required this.onHevy,
    this.accent = brandAccent,
    this.onAccent = ink,
    this.selection = _brandSelection,
    this.progressHalf = brandProgressHalf,
    this.slotMorning = _brandMorning,
    this.slotAfternoon = brandAccent,
    this.slotEvening = _brandEvening,
    this.creatineFill = creatine,
    this.knitBase = const Color(0xFF2D3FE0),
    this.knitStitch = const Color(0xFF4657EE),
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

  /// Green of the barcode scan, readable as text and icons on [scanSurface],
  /// the background of the scan button and of the values it filled in.
  final Color scan;
  final Color scanSurface;

  /// Blue of creatine readable as text and icons on the background: the
  /// check of the days it was taken, the marks of the entries holding it.
  final Color creatineText;

  /// Color of the Hevy workouts, such as the dumbbell of the days holding
  /// one: black on the light theme, white on the dark one. [onHevy] is the
  /// one for what sits on it.
  final Color hevy;
  final Color onHevy;

  /// Color of the app, orange: its buttons, the total and the days reached,
  /// the selected tab. [onAccent] is the one for what sits on it.
  final Color accent;
  final Color onAccent;

  /// Selected option of the pill selectors (tabs, sorts, entry modes): a
  /// lighter [accent], so it does not look like an add button.
  final Color selection;

  /// Calendar days at half of their goal or more: a lighter [accent], the
  /// full one marking the goal reached. Halfway between, so it stands apart
  /// from the pale days under half.
  final Color progressHalf;

  /// Colors of the entries added in each part of the day, see [slot].
  final Color slotMorning;
  final Color slotAfternoon;
  final Color slotEvening;

  /// Color of creatine on the screens: its button, its dot, its veil in the
  /// shaker and its days in the calendar. Blue, Christmas green in the
  /// Christmas theme; [creatine] stays the blue of what is shared.
  final Color creatineFill;

  /// Wool of the knitted tab bar of the Christmas theme, and of the stitches
  /// drawn on it.
  final Color knitBase;
  final Color knitStitch;

  /// Blue of creatine: its button, its dot and its veil in the shaker.
  static const creatine = Color(0xFF3FA9F5);

  /// Frame the barcode is placed in, over the camera picture.
  static const scanFrame = Color(0xFF5FD38F);

  /// Orange of the app, whatever the theme: the notifications keep it, and
  /// the share tiles out of Christmas. Read [accent] for the screens.
  static const brandAccent = Color(0xFFFF8A3D);
  static const brandProgressHalf = Color(0xFFFFAC72);
  static const _brandSelection = Color(0xFFFF9854);
  static const _brandMorning = Color(0xFFFFC59E);
  static const _brandEvening = Color(0xFFD9531A);

  /// Dark ink, readable on the orange and on the light fills (creatine, the
  /// parts of the day).
  static const ink = Color(0xFF1B0E05);
  static const danger = Color(0xFFFF5C7A);

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
    scan: Color(0xFF17703F),
    scanSurface: Color(0xFFCDEFD9),
    creatineText: Color(0xFF1A64A3),
    hevy: Color(0xFF000000),
    onHevy: Color(0xFFFFFFFF),
  );

  static const dark = AppColors(
    background: Color(0xFF10142E),
    surface: Color(0xFF1A1F3D),
    surfaceRaised: Color(0xFF272D50),
    text: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFA6ADDD),
    divider: Color(0xFF272D50),
    structure: Color(0xFF7C86DE),
    shakerInside: Color(0xFF1C2142),
    accentText: Color(0xFFFF8A3D),
    scan: Color(0xFF5FD38F),
    scanSurface: Color(0xFF1B3B34),
    creatineText: creatine,
    hevy: Color(0xFFFFFFFF),
    onHevy: Color(0xFF000000),
  );

  /// Christmas red in place of the orange, from December 1 to 25.
  static final christmasLight = light.copyWith(
    accent: _christmasRed,
    onAccent: const Color(0xFFFFFFFF),
    accentText: const Color(0xFFB0182C),
    selection: _christmasSelection,
    progressHalf: _christmasHalf,
    slotMorning: const Color(0xFFF9C2C7),
    slotAfternoon: _christmasHalf,
    slotEvening: _christmasSelection,
    creatineFill: _christmasGreen,
    creatineText: const Color(0xFF1B7A45),
  );

  static final christmasDark = dark.copyWith(
    accent: _christmasRed,
    onAccent: const Color(0xFFFFFFFF),
    accentText: const Color(0xFFFF5A6A),
    selection: _christmasSelection,
    progressHalf: _christmasHalf,
    slotMorning: const Color(0xFFF9C2C7),
    slotAfternoon: _christmasHalf,
    slotEvening: _christmasSelection,
    creatineFill: _christmasGreen,
    creatineText: const Color(0xFF6BD69A),
    knitBase: const Color(0xFF262E6B),
    knitStitch: const Color(0xFF353E80),
  );

  static const _christmasRed = Color(0xFFD7263D);

  /// Fir green of creatine, dark ink staying readable on it.
  static const _christmasGreen = Color(0xFF2E9E5B);

  /// Fir green readable as text and icons on the background of the light
  /// theme, or of the dark one: the tree of the Christmas theme switch.
  static Color christmasGreenText(Brightness brightness) =>
      brightness == Brightness.light
      ? christmasLight.creatineText
      : christmasDark.creatineText;

  /// Lighter reds, dark ink staying readable on them.
  static const _christmasSelection = Color(0xFFE0485C);
  static const _christmasHalf = Color(0xFFEE8592);

  /// Color of the entries added during [slot].
  Color slot(DaySlot slot) => switch (slot) {
    DaySlot.morning => slotMorning,
    DaySlot.afternoon => slotAfternoon,
    DaySlot.evening => slotEvening,
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
    Color? scan,
    Color? scanSurface,
    Color? creatineText,
    Color? hevy,
    Color? onHevy,
    Color? accent,
    Color? onAccent,
    Color? selection,
    Color? progressHalf,
    Color? slotMorning,
    Color? slotAfternoon,
    Color? slotEvening,
    Color? creatineFill,
    Color? knitBase,
    Color? knitStitch,
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
    scan: scan ?? this.scan,
    scanSurface: scanSurface ?? this.scanSurface,
    creatineText: creatineText ?? this.creatineText,
    hevy: hevy ?? this.hevy,
    onHevy: onHevy ?? this.onHevy,
    accent: accent ?? this.accent,
    onAccent: onAccent ?? this.onAccent,
    selection: selection ?? this.selection,
    progressHalf: progressHalf ?? this.progressHalf,
    slotMorning: slotMorning ?? this.slotMorning,
    slotAfternoon: slotAfternoon ?? this.slotAfternoon,
    slotEvening: slotEvening ?? this.slotEvening,
    creatineFill: creatineFill ?? this.creatineFill,
    knitBase: knitBase ?? this.knitBase,
    knitStitch: knitStitch ?? this.knitStitch,
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
      scan: mix(scan, other.scan),
      scanSurface: mix(scanSurface, other.scanSurface),
      creatineText: mix(creatineText, other.creatineText),
      hevy: mix(hevy, other.hevy),
      onHevy: mix(onHevy, other.onHevy),
      accent: mix(accent, other.accent),
      onAccent: mix(onAccent, other.onAccent),
      selection: mix(selection, other.selection),
      progressHalf: mix(progressHalf, other.progressHalf),
      slotMorning: mix(slotMorning, other.slotMorning),
      slotAfternoon: mix(slotAfternoon, other.slotAfternoon),
      slotEvening: mix(slotEvening, other.slotEvening),
      creatineFill: mix(creatineFill, other.creatineFill),
      knitBase: mix(knitBase, other.knitBase),
      knitStitch: mix(knitStitch, other.knitStitch),
    );
  }
}

abstract final class AppTheme {
  static final ThemeData light = _build(AppColors.light, Brightness.light);
  static final ThemeData dark = _build(AppColors.dark, Brightness.dark);

  /// From December 1 to 25, see `christmasActiveProvider`.
  static final ThemeData christmasLight = _build(
    AppColors.christmasLight,
    Brightness.light,
  );
  static final ThemeData christmasDark = _build(
    AppColors.christmasDark,
    Brightness.dark,
    lightColors: AppColors.christmasLight,
  );

  /// [lightColors] are those of the light theme going with [colors], which
  /// the snack bars of the dark theme, white, use.
  static ThemeData _build(
    AppColors colors,
    Brightness brightness, {
    AppColors lightColors = AppColors.light,
  }) {
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
      labelLarge: body(14, FontWeight.w600, colors.onAccent),
      labelSmall: body(11, FontWeight.w500, colors.textSecondary),
    );

    final radius = BorderRadius.circular(10);

    return ThemeData(
      brightness: brightness,
      fontFamily: _bodyFont,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: colors.accent,
        onPrimary: colors.onAccent,
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
      // The sheets of the menu, on the page background.
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.background,
        modalBackgroundColor: colors.background,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        foregroundColor: colors.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.headlineSmall,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.accent,
          foregroundColor: colors.onAccent,
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
          borderSide: BorderSide(color: colors.accent, width: 1.5),
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
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colors.accent,
        selectionHandleColor: colors.accent,
      ),
      dividerTheme: DividerThemeData(color: colors.divider, thickness: 1),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) &&
                  !states.contains(WidgetState.disabled)
              ? colors.accent
              : null,
        ),
        checkColor: WidgetStatePropertyAll(colors.onAccent),
        side: BorderSide(color: colors.textSecondary, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      // The arrow of the icon set of the app, on every page going back.
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (context) => const Icon(LucideIcons.arrowLeft),
      ),
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
            ? colors.accent
            : lightColors.accentText,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
