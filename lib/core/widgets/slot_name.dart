import 'package:protein_calculator/core/domain/day_slot.dart';
import 'package:protein_calculator/l10n/app_localizations.dart';

extension SlotName on AppLocalizations {
  /// Name of [slot], the part of the day: "Morning", "Matin".
  String slotName(DaySlot slot) => switch (slot) {
    DaySlot.morning => slotMorning,
    DaySlot.afternoon => slotAfternoon,
    DaySlot.evening => slotEvening,
  };
}
