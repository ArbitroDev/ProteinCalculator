import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protein_calculator/core/domain/day_slot.dart';
import 'package:protein_calculator/core/theme.dart';

void main() {
  test('the usual themes are orange', () {
    expect(AppTheme.light.colorScheme.primary, const Color(0xFFFF8A3D));
    expect(AppTheme.dark.colorScheme.primary, const Color(0xFFFF8A3D));
    expect(AppColors.light.slot(DaySlot.afternoon), AppColors.brandAccent);
  });

  test('the Christmas themes are red, with white on it', () {
    for (final theme in [AppTheme.christmasLight, AppTheme.christmasDark]) {
      expect(theme.colorScheme.primary, const Color(0xFFD7263D));
      expect(theme.colorScheme.onPrimary, const Color(0xFFFFFFFF));
    }
    expect(AppColors.christmasLight.accentText, const Color(0xFFB0182C));
    expect(AppColors.christmasDark.accentText, const Color(0xFFFF5A6A));
    expect(AppColors.christmasDark.knitBase, const Color(0xFF262E6B));
    // Creatine turns fir green, blue the rest of the year.
    expect(AppColors.christmasLight.creatineFill, const Color(0xFF2E9E5B));
    expect(AppColors.light.creatineFill, AppColors.creatine);
  });
}
