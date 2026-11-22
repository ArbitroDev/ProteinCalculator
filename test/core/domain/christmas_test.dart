import 'package:flutter_test/flutter_test.dart';
import 'package:protein_calculator/core/domain/app_day.dart';
import 'package:protein_calculator/core/domain/christmas.dart';

void main() {
  tearDown(() => appDayStartHour = defaultAppDayStartHour);

  test('the season runs from December 1 to 25', () {
    expect(isChristmasSeason(20261130), isFalse);
    expect(isChristmasSeason(20261201), isTrue);
    expect(isChristmasSeason(20261224), isTrue);
    expect(isChristmasSeason(20261225), isTrue);
    expect(isChristmasSeason(20261226), isFalse);
    expect(isChristmasSeason(20270101), isFalse);
    expect(isChristmasSeason(20271210), isTrue);
  });

  test('counts the days left until Christmas', () {
    expect(daysUntilChristmas(20261201), 24);
    expect(daysUntilChristmas(20261215), 10);
    expect(daysUntilChristmas(20261224), 1);
    expect(daysUntilChristmas(20261225), 0);
  });

  test('the season ends when the app day of December 26 starts', () {
    expect(christmasSeasonEnd(20261201, 4), DateTime(2026, 12, 26, 4));
    expect(christmasSeasonEnd(20271225, 0), DateTime(2027, 12, 26));
  });

  test('follows the start hour of the app day', () {
    appDayStartHour = 3;
    // Still November 30 for the app.
    expect(isChristmasSeason(dayKeyOf(DateTime(2026, 12, 1, 2))), isFalse);
    expect(isChristmasSeason(dayKeyOf(DateTime(2026, 12, 1, 3))), isTrue);
    // Christmas night still counts.
    expect(isChristmasSeason(dayKeyOf(DateTime(2026, 12, 26, 2))), isTrue);
  });
}
