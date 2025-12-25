import '../models/medication.dart';
import '../models/dose_log.dart';

class AdherenceUtils {
  /// Calculates a score from 0.0 to 1.0 for a specific date.
  /// Returns -1.0 if no medications were scheduled for that day.
  static double calculateAdherenceForDay(
      DateTime date,
      List<Medication> meds,
      Map<int, List<DoseLog>> logs
      ) {
    int totalScheduled = 0;
    int totalTaken = 0;

    for (var med in meds) {
      if (_isMedicationScheduledForDay(med, date)) {
        totalScheduled++;

        final medLogs = logs[med.id] ?? [];
        final taken = medLogs.any((log) =>
        log.takenAt.year == date.year &&
            log.takenAt.month == date.month &&
            log.takenAt.day == date.day);

        if (taken) totalTaken++;
      }
    }

    if (totalScheduled == 0) return -1.0;
    return totalTaken / totalScheduled;
  }

  static bool _isMedicationScheduledForDay(Medication med, DateTime date) {
    // Only count if the date is today or in the past relative to the start date
    if (date.isBefore(med.scheduledTime) &&
        !(date.year == med.scheduledTime.year &&
            date.month == med.scheduledTime.month &&
            date.day == med.scheduledTime.day)) {
      return false;
    }

    final diff = DateTime(date.year, date.month, date.day)
        .difference(DateTime(med.scheduledTime.year, med.scheduledTime.month, med.scheduledTime.day))
        .inDays;

    switch (med.frequencyType) {
      case FrequencyType.daily:
        return true;
      case FrequencyType.everyXDays:
        return diff % med.frequencyInterval == 0;
      case FrequencyType.weekly:
        return diff % (7 * med.frequencyInterval) == 0;
    }
  }
}