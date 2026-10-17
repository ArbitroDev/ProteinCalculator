import 'package:flutter/foundation.dart';

/// Smallest and largest creatine dose, in grams with one decimal at most,
/// and the dose offered when creatine is first turned on.
const minCreatineDoseGrams = 1.0;
const maxCreatineDoseGrams = 50.0;
const defaultCreatineDoseGrams = 5.0;

/// Most creatine doses in one entry or one product.
const maxCreatineDoses = 9;

/// Whether [grams] is a creatine dose the menu accepts: between
/// [minCreatineDoseGrams] and [maxCreatineDoseGrams], with one decimal at
/// most.
bool isValidCreatineDoseGrams(double grams) =>
    grams >= minCreatineDoseGrams &&
    grams <= maxCreatineDoseGrams &&
    (grams * 10 - (grams * 10).roundToDouble()).abs() < 1e-6;

/// Whether [doses] is a number of creatine doses an entry or a product can
/// hold: from 0 to [maxCreatineDoses].
bool isValidCreatineDoses(int doses) => doses >= 0 && doses <= maxCreatineDoses;

/// Creatine settings: whether the user tracks it, and the grams of one dose.
@immutable
class CreatineSettings {
  const CreatineSettings({required this.enabled, required this.doseGrams});

  final bool enabled;

  /// Grams of one dose; null until creatine is first turned on.
  final double? doseGrams;

  /// Whether creatine was ever turned on, even if it is off now.
  bool get everEnabled => doseGrams != null;

  @override
  bool operator ==(Object other) =>
      other is CreatineSettings &&
      other.enabled == enabled &&
      other.doseGrams == doseGrams;

  @override
  int get hashCode => Object.hash(enabled, doseGrams);

  @override
  String toString() => 'CreatineSettings($enabled, $doseGrams g)';
}
