/// The Christmas season, when the app dresses for Christmas if the user
/// leaves it on: from December 1 to 25, in app days.
bool isChristmasSeason(int dayKey) {
  final month = dayKey ~/ 100 % 100;
  final day = dayKey % 100;
  return month == 12 && day <= 25;
}

/// Days left until Christmas from the app day [dayKey] of the season: 24 on
/// December 1, 0 on Christmas day.
int daysUntilChristmas(int dayKey) => 25 - dayKey % 100;
